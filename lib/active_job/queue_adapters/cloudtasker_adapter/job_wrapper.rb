# frozen_string_literal: true

# ActiveJob docs: http://edgeguides.rubyonrails.org/active_job_basics.html
# Example adapters ref: https://github.com/rails/rails/tree/master/activejob/lib/active_job/queue_adapters

module ActiveJob
  module QueueAdapters
    class CloudtaskerAdapter #:nodoc:
      class JobWrapper #:nodoc:
        include Cloudtasker::Worker

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
