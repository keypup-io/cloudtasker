# frozen_string_literal: true

require 'google/cloud/tasks'

module Cloudtasker
  # Build, serialize and schedule tasks on the processing backend.
  class WorkerHandler
    attr_reader :worker

    # Alrogith used to sign the verification token
    JWT_ALG = 'HS256'

    # Sub-namespace to use for redis keys when storing
    # payloads in Redis
    REDIS_PAYLOAD_NAMESPACE = 'payload'

    #
    # Return a namespaced key
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
    # Return the cloudtasker redis client
    #
    # @return [Cloudtasker::RedisClient] The cloudtasker redis client.
    #
    def self.redis
      @redis ||= begin
        require 'cloudtasker/redis_client'
        RedisClient.new
      end
    end

    #
    # Log error on execution failure.
    #
    # @param [Cloudtasker::Worker, nil] worker The worker.
    # @param [Exception] error The error to log.
    #
    # @void
    #
    def self.log_execution_error(worker, error)
      # ActiveJob has its own error logging. No need to double log the error.
      # Note: we use string matching instead of class matching as
      # ActiveJob::QueueAdapters::CloudtaskerAdapter::JobWrapper might not be loaded
      return if worker.class.to_s =~ /^ActiveJob::/

      # Choose logger to use based on context
      # Worker will be nil on InvalidWorkerError - in that case we use generic logging
      logger = worker&.logger || Cloudtasker.logger

      # Log error
      logger.error(error)
    end

    #
    # Execute a task worker from a task payload
    #
    # @param [Hash] input_payload The Cloud Task payload.
    #
    # @return [Any] The return value of the worker perform method.
    #
    def self.execute_from_payload!(input_payload)
      with_worker_handling(input_payload, &:execute)
    end

    #
    # Local middleware used to retrieve the job arg payload from cache
    # if a arg payload reference is present.
    #
    # @param [Hash] payload The full job payload
    #
    # @yield [Hash] The actual payload to use to process the job.
    #
    # @return [Any] The block result
    #
    def self.with_worker_handling(input_payload)
      # Extract payload information
      extracted_payload = extract_payload(input_payload)
      payload = extracted_payload[:payload]
      args_payload_key = extracted_payload[:args_payload_key]

      # Build worker
      worker = Cloudtasker::Worker.from_hash(payload) || raise(InvalidWorkerError)

      # Yied worker
      resp = yield(worker)

      # Delete stored args payload if job has completed
      redis.del(args_payload_key) if args_payload_key && !worker.job_reenqueued

      resp
    rescue DeadWorkerError => e
      # Delete stored args payload if job is dead
      redis.del(args_payload_key) if args_payload_key
      log_execution_error(worker, e)
      Cloudtasker.config.on_dead.call(e, worker)
      raise(e)
    rescue StandardError => e
      log_execution_error(worker, e)
      Cloudtasker.config.on_error.call(e, worker)
      raise(e)
    end

    #
    # Return the argument payload key (if present) along with the actual worker payload.
    #
    # If the payload was stored in Redis then retrieve it.
    #
    # @return [Hash] Hash
    #
    def self.extract_payload(input_payload)
      # Get references
      payload = JSON.parse(input_payload.to_json, symbolize_names: true)
      args_payload_id = payload.delete(:job_args_payload_id)
      args_payload_key = args_payload_id ? key([REDIS_PAYLOAD_NAMESPACE, args_payload_id].join('/')) : nil

      # Retrieve the actual worker args payload
      args_payload = args_payload_key ? redis.fetch(args_payload_key) : payload[:job_args]

      # Return the payload
      {
        args_payload_key: args_payload_key,
        payload: payload.merge(job_args: args_payload)
      }
    end

    #
    # Prepare a new cloud task.
    #
    # @param [Cloudtasker::Worker] worker The worker instance.
    #
    def initialize(worker)
      @worker = worker
    end

    #
    # Return the full task configuration sent to Cloud Task
    #
    # @return [Hash] The task body
    #
    def task_payload
      {
        http_request: {
          http_method: 'POST',
          url: Cloudtasker.config.processor_url,
          headers: {
            Cloudtasker::Config::CONTENT_TYPE_HEADER => 'application/json',
            Cloudtasker::Config::AUTHORIZATION_HEADER => "Bearer #{Authenticator.verification_token}"
          },
          body: worker_payload.to_json
        },
        dispatch_deadline: worker.dispatch_deadline.to_i,
        queue: worker.job_queue
      }
    end

    #
    # Return true if the worker args must be stored in Redis.
    #
    # @return [Boolean] True if the payload must be stored in redis.
    #
    def store_payload_in_redis?
      Cloudtasker.config.redis_payload_storage_threshold &&
        worker.job_args.to_json.bytesize > (Cloudtasker.config.redis_payload_storage_threshold * 1024)
    end

    #
    # Return the payload to use for job arguments. This payload
    # is merged inside the #worker_payload.
    #
    # If the argument payload must be stored in Redis then returns:
    # `{ job_args_payload_id: <worker_id> }`
    #
    # If the argument payload must be natively handled by the backend
    # then returns:
    # `{ job_args: [...] }`
    #
    # @return [Hash] The worker args payload.
    #
    def worker_args_payload
      @worker_args_payload ||= begin
        if store_payload_in_redis?
          # Store payload in Redis
          self.class.redis.write(
            self.class.key([REDIS_PAYLOAD_NAMESPACE, worker.job_id].join('/')),
            worker.job_args
          )

          # Return reference to args payload
          { job_args_payload_id: worker.job_id }
        else
          # Return regular job args payload
          { job_args: worker.job_args }
        end
      end
    end

    #
    # Return the task payload that Google Task will eventually
    # send to the job processor.
    #
    # The payload includes the worker name and the arguments to
    # pass to the worker.
    #
    # The worker arguments should use primitive types as much
    # as possible as all arguments will be serialized to JSON.
    #
    # @return [Hash] The job payload
    #
    def worker_payload
      @worker_payload ||= {
        worker: worker.job_class_name,
        job_queue: worker.job_queue,
        job_id: worker.job_id,
        job_meta: worker.job_meta.to_h
      }.merge(worker_args_payload)
    end

    #
    # Schedule the task on GCP Cloud Task.
    #
    # @param [Integer, nil] time_at A unix timestamp specifying when to run the job.
    #   Leave to `nil` to run now.
    #
    # @return [Cloudtasker::CloudTask] The Google Task response
    #
    def schedule(time_at: nil)
      # Generate task payload
      task = task_payload.merge(schedule_time: time_at).compact

      # Create and return remote task
      CloudTask.create(task)
    end
  end
end
