# frozen_string_literal: true

# ActiveJob docs: http://edgeguides.rubyonrails.org/active_job_basics.html
# Example adapters ref: https://github.com/rails/rails/tree/master/activejob/lib/active_job/queue_adapters

module ActiveJob
  module QueueAdapters
    class CloudtaskerAdapter
      # == Job Wrapper for the Cloudtasker adapter
      #
      # Executes jobs scheduled by the Cloudtasker ActiveJob adapter
      class JobWrapper #:nodoc:
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

          job_serialization.merge! 'job_id' => job_id,
                                   'queue_name' => job_queue,
                                   'provider_job_id' => task_id,
                                   'executions' => job_executions,
                                   'priority' => nil

          Base.execute job_serialization
        end
      end
    end
  end
end
