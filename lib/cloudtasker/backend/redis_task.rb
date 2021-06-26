# frozen_string_literal: true

require 'cloudtasker/redis_client'
require 'net/http'

module Cloudtasker
  module Backend
    # Manage local tasks pushed to Redis
    class RedisTask
      attr_reader :id, :http_request, :schedule_time, :retries, :queue, :dispatch_deadline

      RETRY_INTERVAL = 20 # seconds

      #
      # Return the cloudtasker redis client
      #
      # @return [Cloudtasker::RedisClient] The cloudtasker redis client..
      #
      def self.redis
        @redis ||= RedisClient.new
      end

      #
      # Return a namespaced key.
      #
      # @param [String, Symbol, nil] val The key to namespace
      #
      # @return [String] The namespaced key.
      #
      def self.key(val = nil)
        [to_s.underscore, val].compact.map(&:to_s).join('/')
      end

      #
      # Return all tasks stored in Redis.
      #
      # @return [Array<Cloudtasker::Backend::RedisTask>] All the tasks.
      #
      def self.all
        if redis.exists?(key)
          # Use Schedule Set if available
          redis.smembers(key).map { |id| find(id) }.compact
        else
          # Fallback to redis key matching and migrate tasks
          # to use Task Set instead.
          redis.search(key('*')).map do |gid|
            task_id = gid.sub(key(''), '')
            redis.sadd(key, task_id)
            find(task_id)
          end
        end
      end

      #
      # Reeturn all tasks ready to process.
      #
      # @param [String] queue The queue to retrieve items from.
      #
      # @return [Array<Cloudtasker::Backend::RedisTask>] All the tasks ready to process.
      #
      def self.ready_to_process(queue = nil)
        list = all.select { |e| e.schedule_time <= Time.now }
        list = list.select { |e| e.queue == queue } if queue
        list
      end

      #
      # Retrieve and remove a task from the queue.
      #
      # @param [String] queue The queue to retrieve items from.
      #
      # @return [Cloudtasker::Backend::RedisTask] A task ready to process.
      #
      def self.pop(queue = nil)
        redis.with_lock('cloudtasker/server') do
          ready_to_process(queue).first&.tap(&:destroy)
        end
      end

      #
      # Push a job to the queue.
      #
      # @param [Hash] payload The Cloud Task payload.
      #
      def self.create(payload)
        id = SecureRandom.uuid
        payload = payload.merge(schedule_time: payload[:schedule_time].to_i)

        # Save job
        redis.write(key(id), payload)
        redis.sadd(key, id)
        new(**payload.merge(id: id))
      end

      #
      # Get a task by id.
      #
      # @param [String] id The id of the task.
      #
      # @return [Cloudtasker::Backend::RedisTask, nil] The task.
      #
      def self.find(id)
        gid = key(id)
        return nil unless (payload = redis.fetch(gid))

        new(**payload.merge(id: id))
      end

      #
      # Delete a task by id.
      #
      # @param [String] id The task id.
      #
      def self.delete(id)
        redis.srem(key, id)
        redis.del(key(id))
      end

      #
      # Build a new instance of the class.
      #
      # @param [String] id The ID of the task.
      # @param [Hash] http_request The HTTP request content.
      # @param [Integer] schedule_time When to run the task (Unix timestamp)
      # @param [Integer] retries The number of times the job failed.
      # @param [Integer] dispatch_deadline The dispatch_deadline in seconds.
      #
      def initialize(id:, http_request:, schedule_time: nil, retries: 0, queue: nil, dispatch_deadline: nil)
        @id = id
        @http_request = http_request
        @schedule_time = Time.at(schedule_time || 0)
        @retries = retries || 0
        @queue = queue || Config::DEFAULT_JOB_QUEUE
        @dispatch_deadline = dispatch_deadline || Config::DEFAULT_DISPATCH_DEADLINE
      end

      #
      # Return the redis client.
      #
      # @return [Class] The RedisClient.
      #
      def redis
        self.class.redis
      end

      #
      # Return a hash description of the task.
      #
      # @return [Hash] A hash description of the task.
      #
      def to_h
        {
          id: id,
          http_request: http_request,
          schedule_time: schedule_time.to_i,
          retries: retries,
          queue: queue,
          dispatch_deadline: dispatch_deadline
        }
      end

      #
      # Return the namespaced task id
      #
      # @return [<Type>] The namespaced task id
      #
      def gid
        self.class.key(id)
      end

      #
      # Retry the task later.
      #
      # @param [Integer] interval The delay in seconds before retrying the task
      # @param [Hash] opts Additional options
      # @option opts [Boolean] :is_error Increase number of retries. Default to true.
      #
      def retry_later(interval, opts = {})
        is_error = opts.to_h.fetch(:is_error, true)

        redis.write(
          gid,
          retries: is_error ? retries + 1 : retries,
          http_request: http_request,
          schedule_time: (Time.now + interval).to_i,
          queue: queue,
          dispatch_deadline: dispatch_deadline
        )
        redis.sadd(self.class.key, id)
      end

      #
      # Remove the task from the queue.
      #
      def destroy
        self.class.delete(id)
      end

      #
      # Deliver the task to the processing endpoint.
      #
      def deliver
        Cloudtasker.logger.info(format_log_message('Processing task...'))

        # Send request
        resp = http_client.request(request_content)

        # Delete task if successful
        if resp.code.to_s =~ /20\d/
          destroy
          Cloudtasker.logger.info(format_log_message('Task handled successfully'))
        else
          retry_later(RETRY_INTERVAL)
          Cloudtasker.logger.info(format_log_message("Task failure - Retry in #{RETRY_INTERVAL} seconds..."))
        end

        resp
      rescue Net::ReadTimeout
        retry_later(RETRY_INTERVAL)
        Cloudtasker.logger.info(
          format_log_message(
            "Task deadline exceeded (#{dispatch_deadline}s) - Retry in #{RETRY_INTERVAL} seconds..."
          )
        )
      end

      #
      # Equality operator.
      #
      # @param [Any] other The object to compare.
      #
      # @return [Boolean] True if the object is equal.
      #
      def ==(other)
        other.is_a?(self.class) && other.id == id
      end

      private

      #
      # Format a log message
      #
      # @param [String] msg The message to log.
      #
      # @return [String] The formatted message
      #
      def format_log_message(msg)
        "[Cloudtasker/Server][#{id}] #{msg}"
      end

      #
      # Return the HTTP client.
      #
      # @return [Net::HTTP] The http_client.
      #
      def http_client
        @http_client ||=
          begin
            uri = URI(http_request[:url])
            Net::HTTP.new(uri.host, uri.port).tap { |e| e.read_timeout = dispatch_deadline }
          end
      end

      #
      # Return the HTTP request to send
      #
      # @return [Net::HTTP::Post] The http request
      #
      def request_content
        @request_content ||= begin
          uri = URI(http_request[:url])
          req = Net::HTTP::Post.new(uri.path, http_request[:headers])

          # Add task headers
          req[Cloudtasker::Config::TASK_ID_HEADER] = id
          req[Cloudtasker::Config::RETRY_HEADER] = retries

          # Set job payload
          req.body = http_request[:body]
          req
        end
      end
    end
  end
end
