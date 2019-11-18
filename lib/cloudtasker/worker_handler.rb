# frozen_string_literal: true

require 'google/cloud/tasks'

module Cloudtasker
  # Build, serialize and schedule tasks on the processing backend.
  class WorkerHandler
    attr_reader :worker, :job_args

    # Alrogith used to sign the verification token
    JWT_ALG = 'HS256'

    #
    # Execute a task worker from a task payload
    #
    # @param [Hash] payload The Cloud Task payload.
    #
    # @return [Any] The return value of the worker perform method.
    #
    def self.execute_from_payload!(payload)
      worker = Cloudtasker::Worker.from_hash(payload) || raise(InvalidWorkerError)
      worker.execute
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
        worker: worker.class.to_s,
        job_id: worker.job_id,
        job_args: worker.job_args,
        job_meta: worker.job_meta
      }
    end

    #
    # Return a protobuf timestamp specifying how to wait
    # before running a task.
    #
    # @param [Integer, nil] interval The time to wait.
    # @param [Integer, nil] time_at The time at which the job should run.
    #
    # @return [Integer, nil] The Unix timestamp.
    #
    def schedule_time(interval: nil, time_at: nil)
      return nil unless interval || time_at

      # Generate the complete Unix timestamp
      (time_at || Time.now).to_i + interval.to_i
    end

    #
    # Schedule the task on GCP Cloud Task.
    #
    # @param [Integer, nil] interval How to wait before running the task.
    #   Leave to `nil` to run now.
    #
    # @return [Cloudtasker::CloudTask] The Google Task response
    #
    def schedule(interval: nil, time_at: nil)
      # Generate task payload
      task = task_payload.merge(
        schedule_time: schedule_time(interval: interval, time_at: time_at)
      ).compact

      # Create and return remote task
      CloudTask.create(task)
    end
  end
end
