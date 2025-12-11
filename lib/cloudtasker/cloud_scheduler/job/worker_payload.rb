# frozen_string_literal: true

require 'cloudtasker/worker_handler'

module Cloudtasker
  module CloudScheduler
    class Job
      # Payload used to schedule Cloudtasker Workers on Cloud Scheduler
      class WorkerPayload
        attr_reader :worker

        #
        # Build a new instance of the class.
        #
        # @param [Cloudtasker::Worker] worker The Cloudtasker Worker instance.
        #
        def initialize(worker)
          @worker = worker
        end

        #
        # Return the Hash representation of the job payload.
        #
        # @return [Hash] The job payload.
        #
        def to_h
          JSON.parse(request_config[:body])
        end

        private

        #
        # Return the HTTP request configuration for a Cloud Task.
        #
        # @return [Hash] The request configuration.
        #
        def request_config
          worker_handler.task_payload[:http_request]
        end

        #
        # Return the worker handler.
        #
        # @return [Cloudtasker::WorkerHandler] The worker handler.
        #
        def worker_handler
          @worker_handler ||= Cloudtasker::WorkerHandler.new(worker)
        end
      end
    end
  end
end
