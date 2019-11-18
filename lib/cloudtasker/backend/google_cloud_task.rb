# frozen_string_literal: true

require 'cloudtasker/redis_client'

module Cloudtasker
  module Backend
    # Manage tasks pushed to GCP Cloud Task
    class GoogleCloudTask
      attr_accessor :gcp_task

      #
      # Return the Google Cloud Task client.
      #
      # @return [Google::Cloud::Tasks] The Google Cloud Task client.
      #
      def self.client
        @client ||= ::Google::Cloud::Tasks.new(version: :v2beta3)
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
      # @return [String] The queue path.
      #
      def self.queue_path
        client.queue_path(
          config.gcp_project_id,
          config.gcp_location_id,
          config.gcp_queue_id
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
      def self.format_schedule_time(schedule_time)
        return nil unless schedule_time

        # Generate protobuf timestamp
        Google::Protobuf::Timestamp.new.tap { |e| e.seconds = schedule_time.to_i }
      end

      #
      # Find a task by id.
      #
      # @param [String] id The task id.
      #
      # @return [Cloudtasker::Backend::GoogleCloudTask, nil] The retrieved task.
      #
      def self.find(id)
        resp = client.get_task(id)
        resp ? new(resp) : nil
      rescue Google::Gax::RetryError
        nil
      end

      #
      # Create a new task.
      #
      # @param [Hash] payload The task payload.
      #
      # @return [Cloudtasker::Backend::GoogleCloudTask, nil] The created task.
      #
      def self.create(payload)
        # Format payload
        payload = payload.merge(
          schedule_time: format_schedule_time(payload[:schedule_time])
        ).compact

        # Create task
        resp = client.create_task(queue_path, payload)
        resp ? new(resp) : nil
      rescue Google::Gax::RetryError
        nil
      end

      #
      # Delete a task by id.
      #
      # @param [String] id The id of the task.
      #
      def self.delete(id)
        client.delete_task(id)
      rescue Google::Gax::RetryError
        nil
      end

      #
      # Build a new instance of the class.
      #
      # @param [Google::Cloud::Tasks::V2beta3::Task] resp The GCP Cloud Task response
      #
      def initialize(gcp_task)
        @gcp_task = gcp_task
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
          schedule_time: gcp_task.to_h[:schedule_time].to_i
        }
      end
    end
  end
end
