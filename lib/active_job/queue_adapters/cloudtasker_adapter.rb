# frozen_string_literal: true

# ActiveJob docs: http://guides.rubyonrails.org/active_job_basics.html
# Example adapters ref: https://github.com/rails/rails/tree/master/activejob/lib/active_job/queue_adapters

module ActiveJob
  module QueueAdapters
    # == Cloudtasker adapter for Active Job
    #
    # To use Cloudtasker set the queue_adapter config to +:cloudtasker+.
    #
    #   Rails.application.config.active_job.queue_adapter = :cloudtasker
    class CloudtaskerAdapter
      SERIALIZATION_FILTERED_KEYS = [
        'executions', # Given by the worker at processing
        'provider_job_id', # Also given by the worker at processing
        'priority' # Not used
      ].freeze

      ACTIVE_JOB_RETRIAL_SERIALIZATION_FILTERED_KEYS =
        SERIALIZATION_FILTERED_KEYS.without('executions').freeze

      # Enqueues the given ActiveJob instance for execution
      #
      # @param job [ActiveJob::Base] The ActiveJob instance
      #
      # @return [Cloudtasker::CloudTask] The Google Task response
      #
      def enqueue(job)
        build_worker(job).schedule
      end

      # Enqueues the given ActiveJob instance for execution at a given time
      #
      # @param job [ActiveJob::Base] The ActiveJob instance
      # @param precise_timestamp [Integer] The timestamp at which the job must be executed
      #
      # @return [Cloudtasker::CloudTask] The Google Task response
      #
      def enqueue_at(job, precise_timestamp)
        build_worker(job).schedule(time_at: Time.at(precise_timestamp))
      end

      private

      def build_worker(job)
        job_serialization = job.serialize.except(*serialization_filtered_keys)

        JobWrapper.new(
          job_id: job_serialization.delete('job_id'),
          job_queue: job_serialization.delete('queue_name'),
          job_args: [job_serialization]
        )
      end

      def serialization_filtered_keys
        if Cloudtasker.config.retry_mechanism == :active_job
          ACTIVE_JOB_RETRIAL_SERIALIZATION_FILTERED_KEYS
        else
          SERIALIZATION_FILTERED_KEYS
        end
      end

      # == Job Wrapper for the Cloudtasker adapter
      #
      # Executes jobs scheduled by the Cloudtasker ActiveJob adapter
      class JobWrapper # :nodoc:
        include Cloudtasker::Worker

        # Executes the given serialized ActiveJob call.
        # - See https://api.rubyonrails.org/classes/ActiveJob/Core.html#method-i-serialize
        #
        # @param [Hash] job_serialization The serialized ActiveJob call
        #
        # @return [any] The execution of the ActiveJob call
        #
        def perform(job_serialization, *_extra_options)
          job_serialization.merge!(
            'job_id' => job_id,
            'queue_name' => job_queue,
            'provider_job_id' => task_id,
            'priority' => nil
          )

          # Overrides ActiveJob default retry counter with one that tracks Cloudtasker-managed retries
          if Cloudtasker.config.retry_mechanism == :provider
            job_executions = job_retries < 1 ? 0 : (job_retries + 1)
            job_serialization.merge!('executions' => job_executions)
          end

          Base.execute job_serialization
        end
      end
    end
  end
end
