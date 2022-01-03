# frozen_string_literal: true

module Cloudtasker
  module Backend
    # Manage local tasks pushed to memory.
    # Used for testing.
    class MemoryTask
      attr_accessor :job_retries
      attr_reader :id, :http_request, :schedule_time, :queue

      #
      # Return true if we are in test inline execution mode.
      #
      # @return [Boolean] True if inline mode enabled.
      #
      def self.inline_mode?
        defined?(Cloudtasker::Testing) && Cloudtasker::Testing.inline?
      end

      #
      # Return the task queue. A worker class name
      #
      # @return [Array<Hash>] <description>
      #
      def self.queue
        @queue ||= []
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
        task = new(**payload.merge(id: id))
        queue << task

        # Execute task immediately if in testing and inline mode enabled
        task.execute if inline_mode?

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
      def initialize(id:, http_request:, schedule_time: nil, queue: nil, job_retries: 0, **_xargs)
        @id = id
        @http_request = http_request
        @schedule_time = Time.at(schedule_time || 0)
        @queue = queue
        @job_retries = job_retries || 0
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
      # Execute the task.
      #
      # @return [Any] The return value of the worker perform method.
      #
      def execute
        # Execute worker
        worker_payload = payload.merge(job_retries: job_retries, task_id: id)
        resp = WorkerHandler.with_worker_handling(worker_payload, &:execute)

        # Delete task
        self.class.delete(id)
        resp
      rescue DeadWorkerError => e
        self.class.delete(id)
        raise(e) if self.class.inline_mode?
      rescue StandardError => e
        self.job_retries += 1
        raise(e) if self.class.inline_mode?
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
