# frozen_string_literal: true

module Cloudtasker
  module CloudScheduler
    class Job
      # Payload used to schedule ActiveJob jobs on Cloud Scheduler
      class ActiveJobPayload
        attr_reader :worker

        def initialize(worker)
          @worker = worker
        end

        def to_h
          {
            'worker' => 'ActiveJob::QueueAdapters::CloudtaskerAdapter::JobWrapper',
            'job_queue' => worker.queue_name,
            'job_id' => worker.job_id,
            'job_meta' => {},
            'job_args' => [worker.serialize]
          }
        end
      end
    end
  end
end
