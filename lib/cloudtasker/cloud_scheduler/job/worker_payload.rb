# frozen_string_literal: true

require 'cloudtasker/worker_handler'

module Cloudtasker
  module CloudScheduler
    class Job
      # Payload used to schedule Cloudtasker Workers on Cloud Scheduler
      class WorkerPayload
        attr_reader :worker

        def initialize(worker)
          @worker = worker
        end

        def to_h
          JSON.parse(request_config[:body])
        end

        private

        def request_config
          worker_handler.task_payload[:http_request]
        end

        def worker_handler
          @worker_handler ||= Cloudtasker::WorkerHandler.new(worker)
        end
      end
    end
  end
end
