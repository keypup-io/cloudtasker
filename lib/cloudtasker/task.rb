# frozen_string_literal: true

require 'google/cloud/tasks'

module Cloudtasker
  # Build, serialize and schedule tasks on GCP Cloud Task
  class Task
    attr_reader :worker, :job_args

    # Alrogith used to sign the verification token
    JWT_ALG = 'HS256'

    #
    # Return an instantiated worker from a Cloud Task
    # payload.
    #
    # @param [Hash] payload The Cloud Task payload.
    #
    # @return [Any] An intantiated worker.
    #
    def self.worker_from_payload(payload)
      # Extract worker parameters
      klass_name = payload&.dig('worker') || payload&.dig(:worker)
      job_args = payload&.dig('args') || payload&.dig(:args)
      job_id = payload&.dig('id') || payload&.dig(:id)

      # Check that worker class is a valid worker
      worker_klass = Object.const_get(klass_name)
      return nil unless worker_klass.include?(Worker)

      # Return instantiated worker
      worker_klass.new(job_args: job_args, job_id: job_id)
    rescue NameError
      nil
    end

    #
    # Execute a task worker from a task payload
    #
    # @param [Hash] payload The Cloud Task payload.
    #
    # @return [Any] The return value of the worker perform method.
    #
    def self.execute_from_payload!(payload)
      worker = worker_from_payload(payload) || raise(InvalidWorkerError)
      worker.execute
    end

    #
    # Return the Google Cloud Task client.
    #
    # @return [Google::Cloud::Tasks] The Google Cloud Task client.
    #
    def self.client
      @client ||= ::Google::Cloud::Tasks.new(version: :v2beta3)
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
    # Return the Google Cloud Task client.
    #
    # @return [Google::Cloud::Tasks] The Google Cloud Task client.
    #
    def client
      self.class.client
    end

    #
    # Return the cloudtasker configuration. See Cloudtasker#configure.
    #
    # @return [Cloudtasker::Config] The library configuration.
    #
    def config
      Cloudtasker.config
    end

    #
    # Return the fully qualified path for the Cloud Task queue.
    #
    # @return [String] The queue path.
    #
    def queue_path
      client.queue_path(
        config.gcp_project_id,
        config.gcp_location_id,
        config.gcp_queue_id
      )
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
          url: config.processor_url,
          headers: {
            'Content-Type' => 'application/json',
            'Authorization' => "Bearer #{Authenticator.verification_token}"
          },
          body: worker_payload.to_json
        }
      }
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
        id: worker.job_id,
        worker: worker.class.to_s,
        args: worker.job_args
      }
    end

    #
    # Return a protobuf timestamp specifying how to wait
    # before running a task.
    #
    # @param [Integer, nil] interval The time to wait.
    #
    # @return [Google::Protobuf::Timestamp, nil] The protobuff timestamp
    #
    def schedule_time(interval)
      return nil unless interval&.to_i&.positive?

      # Generate protobuf timestamp
      timestamp = Google::Protobuf::Timestamp.new
      timestamp.seconds = Time.now.to_i + interval.to_i
      timestamp
    end

    #
    # Schedule the task on GCP Cloud Task.
    #
    # @param [Integer, nil] interval How to wait before running the task.
    #   Leave to `nil` to run now.
    #
    # @return [Google::Cloud::Tasks::V2beta3::Task] The Google Task response
    #
    def schedule(interval: nil)
      puts interval

      # Generate task payload
      task = task_payload.merge(
        schedule_time: schedule_time(interval)
      ).compact

      # Create and return remote task
      client.create_task(queue_path, task)
    end
  end
end
