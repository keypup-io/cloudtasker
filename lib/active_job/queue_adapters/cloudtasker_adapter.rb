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

      # Determines if enqueuing will check and wait for an associated transaction completes before enqueuing
      #
      # @return [Boolean] True always as this is the default from QueueAdapters::AbstractAdapter
      def enqueue_after_transaction_commit?
        true
      end

      private

      def build_worker(job)
        job_serialization = job.serialize.except(*SERIALIZATION_FILTERED_KEYS)

        JobWrapper.new(
          job_id: job_serialization.delete('job_id'),
          job_queue: job_serialization.delete('queue_name'),
          job_args: [job_serialization]
        )
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
          job_executions = job_retries < 1 ? 0 : (job_retries + 1)

          job_serialization.merge!(
            'job_id' => job_id,
            'queue_name' => job_queue,
            'provider_job_id' => task_id,
            'executions' => job_executions,
            'priority' => nil
          )

          Base.execute job_serialization
        end
      end
    end
  end
end
