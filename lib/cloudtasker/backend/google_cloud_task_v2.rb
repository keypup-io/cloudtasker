# frozen_string_literal: true

require 'google/cloud/tasks'
require 'google/protobuf/duration_pb'
require 'google/protobuf/timestamp_pb'
require 'retriable'

module Cloudtasker
  module Backend
    # Manage tasks pushed to GCP Cloud Task
    class GoogleCloudTaskV2
      attr_accessor :gcp_task

      #
      # Create the queue configured in Cloudtasker if it does not already exist.
      #
      # @param [String] :name The queue name
      # @param [Integer] :concurrency The queue concurrency
      # @param [Integer] :retries The number of retries for the queue
      #
      # @return [Google::Cloud::Tasks::V2::Queue] The queue
      #
      def self.setup_queue(name: nil, concurrency: nil, retries: nil)
        # Build full queue path
        queue_name = name || Cloudtasker::Config::DEFAULT_JOB_QUEUE
        full_queue_name = queue_path(queue_name)

        # Try to get existing queue
        client.get_queue(name: full_queue_name)
      rescue Google::Cloud::NotFoundError
        # Extract options
        queue_concurrency = (concurrency || Cloudtasker::Config::DEFAULT_QUEUE_CONCURRENCY).to_i
        queue_retries = (retries || Cloudtasker::Config::DEFAULT_QUEUE_RETRIES).to_i

        # Create queue on 'not found' error
        client.create_queue(
          parent: client.location_path(project: config.gcp_project_id, location: config.gcp_location_id),
          queue: {
            name: full_queue_name,
            retry_config: { max_attempts: queue_retries },
            rate_limits: { max_concurrent_dispatches: queue_concurrency }
          }
        )
      end

      #
      # Return the Google Cloud Task client.
      #
      # @return [Google::Cloud::Tasks::V2::CloudTasks::Client] The Google Cloud Task client.
      #
      def self.client
        @client ||= ::Google::Cloud::Tasks.cloud_tasks
      end

      #
      # Return the cloudtasker configuration. See Cloudtasker#configure.
      #
      # @return [Cloudtasker::Config] The library configuration.
      #
      def self.config
        Cloudtasker.config
      end

      #
      # Return the fully qualified path for the Cloud Task queue.
      #
      # @param [String] queue_name The relative name of the queue.
      #
      # @return [String] The queue path.
      #
      def self.queue_path(queue_name)
        client.queue_path(
          project: config.gcp_project_id,
          location: config.gcp_location_id,
          queue: [config.gcp_queue_prefix, queue_name].map(&:presence).compact.join('-')
        )
      end

      #
      # Return a protobuf timestamp specifying how to wait
      # before running a task.
      #
      # @param [Integer, nil] schedule_time A unix timestamp.
      #
      # @return [Google::Protobuf::Timestamp, nil] The protobuff timestamp
      #
      def self.format_protobuf_time(schedule_time)
        return nil unless schedule_time

        # Generate protobuf timestamp
        Google::Protobuf::Timestamp.new.tap { |e| e.seconds = schedule_time.to_i }
      end

      #
      # Return a protobuf duration.
      #
      # @param [Integer, nil] duration A duration in seconds.
      #
      # @return [Google::Protobuf::Timestamp, nil] The protobuff timestamp
      #
      def self.format_protobuf_duration(duration)
        return nil unless duration

        # Generate protobuf timestamp
        Google::Protobuf::Duration.new.tap { |e| e.seconds = duration.to_i }
      end

      #
      # Format the job payload sent to Cloud Tasks.
      #
      # @param [Hash] hash The worker payload.
      #
      # @return [Hash] The Cloud Task payload.
      #
      def self.format_task_payload(payload)
        payload = JSON.parse(payload.to_json, symbolize_names: true) # deep dup

        # Format schedule time to Google::Protobuf::Timestamp
        payload[:schedule_time] = format_protobuf_time(payload[:schedule_time])

        # Format dispatch_deadline to Google::Protobuf::Duration
        payload[:dispatch_deadline] = format_protobuf_duration(payload[:dispatch_deadline])

        # Encode job content to support UTF-8.
        # Google Cloud Task expect content to be ASCII-8BIT compatible (binary)
        payload[:http_request][:headers] ||= {}
        payload[:http_request][:headers][Cloudtasker::Config::CONTENT_TYPE_HEADER] = 'text/json'
        payload[:http_request][:headers][Cloudtasker::Config::ENCODING_HEADER] = 'Base64'
        payload[:http_request][:body] = Base64.encode64(payload[:http_request][:body])

        payload.compact
      end

      #
      # Find a task by id.
      #
      # @param [String] id The task id.
      #
      # @return [Cloudtasker::Backend::GoogleCloudTaskV2, nil] The retrieved task.
      #
      def self.find(id)
        resp = with_gapi_retries { client.get_task(name: id) }
        resp ? new(resp) : nil
      rescue Google::Cloud::NotFoundError
        # The ID does not exist
        nil
      end

      #
      # Create a new task.
      #
      # @param [Hash] payload The task payload.
      #
      # @return [Cloudtasker::Backend::GoogleCloudTaskV2, nil] The created task.
      #
      def self.create(payload)
        payload = format_task_payload(payload)

        # Infer full queue name
        relative_queue = payload.delete(:queue)
        full_queue = queue_path(relative_queue)

        # Create task
        resp = with_gapi_retries { client.create_task(parent: full_queue, task: payload) }
        resp ? new(resp) : nil
      end

      #
      # Delete a task by id.
      #
      # @param [String] id The id of the task.
      #
      def self.delete(id)
        with_gapi_retries { client.delete_task(name: id) }
      rescue Google::Cloud::NotFoundError, Google::Cloud::PermissionDeniedError
        # The ID does not exist
        nil
      end

      #
      # Helper method encapsulating the retry strategy for Google API calls
      #
      def self.with_gapi_retries(&block)
        Retriable.retriable(on: [Google::Cloud::UnavailableError], tries: 3, &block)
      end

      #
      # Build a new instance of the class.
      #
      # @param [Google::Cloud::Tasks::V2::Task] resp The GCP Cloud Task response
      #
      def initialize(gcp_task)
        @gcp_task = gcp_task
      end

      #
      # Return the relative queue (queue name minus prefix) the task is in.
      #
      # @return [String] The relative queue name
      #
      def relative_queue
        gcp_task
          .name
          .match(%r{/queues/([^/]+)})
          &.captures
          &.first
          &.sub(/^#{self.class.config.gcp_queue_prefix}-/, '')
      end

      #
      # Return a hash description of the task.
      #
      # @return [Hash] A hash description of the task.
      #
      def to_h
        {
          id: gcp_task.name,
          http_request: gcp_task.to_h[:http_request],
          schedule_time: gcp_task.to_h.dig(:schedule_time, :seconds).to_i,
          dispatch_deadline: gcp_task.to_h.dig(:dispatch_deadline, :seconds).to_i,
          retries: gcp_task.to_h[:response_count],
          queue: relative_queue
        }
      end
    end
  end
end
