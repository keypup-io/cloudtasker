# frozen_string_literal: true

require 'cloudtasker/worker_handler'

module Cloudtasker
  module CloudScheduler
    # Manage cron jobs
    class Job
      #
      # Return all jobs from a hash.
      #
      # @param [Hash] hash The hash to load jobs from.
      #
      # @return [Array<Cloudtasker::CloudScheduler::Job>] The list of jobs.
      #
      def self.load_from_hash!(hash)
        Schedule.load_from_hash!(hash).map do |schedule|
          new(schedule)
        end
      end

      attr_reader :schedule

      #
      # Build a new instance of the class.
      #
      # @param [Cloudtasker::CloudScheduler::Schedule] schedule The schedule to run.
      #
      def initialize(schedule)
        @schedule = schedule
      end

      #
      # Parent folder for all jobs.
      #
      # @return [String] The parent folder.
      #
      def parent
        @parent ||= client.location_path(project: config.gcp_project_id, location: config.gcp_location_id)
      end

      #
      # Prefix for all jobs.
      #
      # @return [String] The job prefix.
      #
      def prefix
        "#{parent}/jobs/#{config.gcp_queue_prefix}--"
      end

      #
      # Return name of the job in the remote scheduler.
      #
      # @return [String] The job name.
      #
      def remote_name
        "#{prefix}#{schedule.id}"
      end

      #
      # Return the job name.
      #
      # @return [String] The job name.
      #
      def name
        schedule.id
      end

      #
      # Create the job in the remote scheduler.
      #
      # @return [Google::Cloud::Scheduler::V1::Job] The job instance.
      #
      def create!
        client.create_job(parent: parent, job: to_request_body)
      end

      #
      # Update the job in the remote scheduler.
      #
      # @return [Google::Cloud::Scheduler::V1::Job] The job instance.
      #
      def update!
        client.update_job(job: to_request_body)
      end

      #
      # Delete the job from the remote scheduler.
      #
      # @return [Google::Protobuf::Empty] The job instance.
      #
      def delete!
        client.delete_job(name: remote_name)
      end

      #
      # Return a hash that can be used to create/update a job in the remote scheduler.
      #
      # @return [Hash<Symbol, String>] The job hash.
      #
      def to_request_body
        {
          name: remote_name,
          schedule: schedule.cron,
          time_zone: schedule.time_zone,
          http_target: {
            uri: request_config[:url],
            http_method: request_config[:http_method],
            headers: request_config[:headers],
            body: request_config[:body]
          }
        }
      end

      private

      def request_config
        schedule.worker_handler.task_payload[:http_request]
      end

      def config
        @config ||= Cloudtasker.config
      end

      def client
        @client ||= Google::Cloud::Scheduler.cloud_scheduler
      end
    end
  end
end
