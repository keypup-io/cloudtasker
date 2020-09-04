# ActiveJob docs: http://edgeguides.rubyonrails.org/active_job_basics.html
# Example adapters ref: https://github.com/rails/rails/tree/master/activejob/lib/active_job/queue_adapters

module ActiveJob
  module QueueAdapters
    class CloudtaskerAdapter #:nodoc:
      class JobWrapper #:nodoc:
        include Cloudtasker::Worker

        def perform(job_serialization, *opts)
          Base.execute job_serialization
        end
      end
    end
  end
end