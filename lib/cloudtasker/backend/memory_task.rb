# frozen_string_literal: true

require 'cloudtasker/redis_client'

module Cloudtasker
  module Backend
    # Manage local tasks pushed to memory.
    # Used for testing.
    class MemoryTask
      attr_reader :id, :http_request, :schedule_time, :queue

      #
      # Return the task queue. A worker class name
      #
      # @return [Array<Hash>] <description>
      #
      def self.queue
        @queue ||= []
      end

      #
      # Return the workers currently in the queue.
      #
      # @param [String] worker_class_name Filter jobs on worker class name.
      #
      # @return [Array<Cloudtasker::Worker] The list of workers
      #
      def self.jobs(worker_class_name = nil)
        all(worker_class_name).map(&:worker)
      end

      #
      # Run all Tasks in the queue. Optionally filter which tasks to run based
      # on the worker class name.
      #
      # @param [String] worker_class_name Run tasks for a specific worker class name.
      #
      # @return [Array<any>] The return values of the workers perform method.
      #
      def self.drain(worker_class_name = nil)
        all(worker_class_name).map(&:execute)
      end

      #
      # Return all enqueued tasks. A worker class name can be specified
      # to filter the returned results.
      #
      # @param [String] worker_class_name Filter tasks on worker class name.
      #
      # @return [Array<Cloudtasker::Backend::MemoryTask>] All the tasks
      #
      def self.all(worker_class_name = nil)
        list = queue
        list = list.select { |e| e.worker_class_name == worker_class_name } if worker_class_name
        list
      end

      #
      # Push a job to the queue.
      #
      # @param [Hash] payload The Cloud Task payload.
      #
      def self.create(payload)
        id = payload[:id] || SecureRandom.uuid
        payload = payload.merge(schedule_time: payload[:schedule_time].to_i)

        # Save task
        task = new(payload.merge(id: id))
        queue << task

        # Execute task immediately if in testing and inline mode enabled
        task.execute if defined?(Cloudtasker::Testing) && Cloudtasker::Testing.inline?

        task
      end

      #
      # Get a task by id.
      #
      # @param [String] id The id of the task.
      #
      # @return [Cloudtasker::Backend::MemoryTask, nil] The task.
      #
      def self.find(id)
        queue.find { |e| e.id == id }
      end

      #
      # Delete a task by id.
      #
      # @param [String] id The task id.
      #
      def self.delete(id)
        queue.reject! { |e| e.id == id }
      end

      #
      # Clear the queue.
      #
      # @param [String] worker_class_name Filter jobs on worker class name.
      #
      # @return [Array<Cloudtasker::Backend::MemoryTask>] The updated queue
      #
      def self.clear(worker_class_name = nil)
        if worker_class_name
          queue.reject! { |e| e.worker_class_name == worker_class_name }
        else
          queue.clear
        end
      end

      #
      # Build a new instance of the class.
      #
      # @param [String] id The ID of the task.
      # @param [Hash] http_request The HTTP request content.
      # @param [Integer] schedule_time When to run the task (Unix timestamp)
      #
      def initialize(id:, http_request:, schedule_time: nil, queue: nil)
        @id = id
        @http_request = http_request
        @schedule_time = Time.at(schedule_time || 0)
        @queue = queue
      end

      #
      # Return task payload.
      #
      # @return [Hash] The task payload.
      #
      def payload
        @payload ||= JSON.parse(http_request.dig(:body), symbolize_names: true)
      end

      #
      # Return the worker class from the task payload.
      #
      # @return [String] The task worker class name.
      #
      def worker_class_name
        payload[:worker]
      end

      #
      # Return a hash description of the task.
      #
      # @return [Hash] A hash description of the task.
      #
      def to_h
        {
          id: id,
          http_request: http_request,
          schedule_time: schedule_time.to_i,
          queue: queue
        }
      end

      #
      # Return the worker attached to this task.
      #
      # @return [Cloudtasker::Worker] The task worker.
      #
      def worker
        @worker ||= Worker.from_hash(payload)
      end

      #
      # Execute the task.
      #
      # @return [Any] The return value of the worker perform method.
      #
      def execute
        resp = worker.execute
        self.class.delete(id)
        resp
      rescue StandardError
        worker.job_retries += 1
      end

      #
      # Equality operator.
      #
      # @param [Any] other The object to compare.
      #
      # @return [Boolean] True if the object is equal.
      #
      def ==(other)
        other.is_a?(self.class) && other.id == id
      end
    end
  end
end
