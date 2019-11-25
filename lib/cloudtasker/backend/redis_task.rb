# frozen_string_literal: true

require 'cloudtasker/redis_client'
require 'net/http'

module Cloudtasker
  module Backend
    # Manage local tasks pushed to Redis
    class RedisTask
      attr_reader :id, :http_request, :schedule_time, :retries

      RETRY_INTERVAL = 20 # seconds

      #
      # Return the cloudtasker redis client
      #
      # @return [Class] The redis client.
      #
      def self.redis
        RedisClient
      end

      #
      # Return a namespaced key.
      #
      # @param [String, Symbol] val The key to namespace
      #
      # @return [String] The namespaced key.
      #
      def self.key(val)
        return nil if val.nil?

        [to_s.underscore, val.to_s].join('/')
      end

      #
      # Return all tasks stored in Redis.
      #
      # @return [Array<Cloudtasker::Backend::RedisTask>] All the tasks.
      #
      def self.all
        redis.search(key('*')).map do |gid|
          payload = redis.fetch(gid)
          new(payload.merge(id: gid.sub(key(''), '')))
        end
      end

      #
      # Reeturn all tasks ready to process.
      #
      # @return [Array<Cloudtasker::Backend::RedisTask>] All the tasks ready to process.
      #
      def self.ready_to_process
        all.select { |e| e.schedule_time <= Time.now }
      end

      #
      # Retrieve and remove a task from the queue.
      #
      # @return [Cloudtasker::Backend::RedisTask] A task ready to process.
      #
      def self.pop
        redis.with_lock('cloudtasker/server') do
          ready_to_process.first&.tap(&:destroy)
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
        new(payload.merge(id: id))
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

        new(payload.merge(id: id))
      end

      #
      # Delete a task by id.
      #
      # @param [String] id The task id.
      #
      def self.delete(id)
        redis.del(key(id))
      end

      #
      # Build a new instance of the class.
      #
      # @param [String] id The ID of the task.
      # @param [Hash] http_request The HTTP request content.
      # @param [Integer] schedule_time When to run the task (Unix timestamp)
      # @param [Integer] retries The number of times the job failed.
      #
      def initialize(id:, http_request:, schedule_time: nil, retries: 0)
        @id = id
        @http_request = http_request
        @schedule_time = Time.at(schedule_time || 0)
        @retries = retries || 0
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
          retries: retries
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
      #
      def retry_later(interval, is_error: true)
        redis.write(gid,
                    retries: is_error ? retries + 1 : retries,
                    http_request: http_request,
                    schedule_time: (Time.now + interval).to_i)
      end

      #
      # Remove the task from the queue.
      #
      def destroy
        redis.del(gid)
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
            Net::HTTP.new(uri.host, uri.port).tap { |e| e.read_timeout = 60 * 10 }
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

          # Add retries header
          req['X-CloudTasks-TaskExecutionCount'] = retries

          # Set job payload
          req.body = http_request[:body]
          req
        end
      end
    end
  end
end
