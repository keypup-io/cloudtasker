# frozen_string_literal: true

require 'google/cloud/scheduler/v1'
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
      # Prefix for all jobs that includes the parent path and the queue prefix.
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
        client.create_job(parent: parent, job: payload)
      end

      #
      # Update the job in the remote scheduler.
      #
      # @return [Google::Cloud::Scheduler::V1::Job] The job instance.
      #
      def update!
        client.update_job(job: payload)
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
      def payload
        {
          name: remote_name,
          schedule: schedule.cron,
          time_zone: schedule.time_zone,
          http_target: {
            http_method: 'POST',
            uri: config.processor_url,
            oidc_token: config.oidc,
            body: schedule.job_payload.to_json,
            headers: {
              Cloudtasker::Config::CONTENT_TYPE_HEADER => 'application/json',
              Cloudtasker::Config::CT_AUTHORIZATION_HEADER => Authenticator.bearer_token
            }.compact
          }.compact
        }
      end

      private

      #
      # Return the parent path for all jobs.
      #
      # @return [String] The parent path.
      #
      def parent
        @parent ||= client.location_path(project: config.gcp_project_id, location: config.gcp_location_id)
      end

      #
      # Return the Cloudtasker configuration.
      #
      # @return [Cloudtasker::Config] The configuration.
      #
      def config
        @config ||= Cloudtasker.config
      end

      #
      # Return the Cloud Scheduler client.
      #
      # @return [Google::Cloud::Scheduler::V1::CloudSchedulerClient] The client.
      #
      def client
        @client ||= Google::Cloud::Scheduler.cloud_scheduler
      end
    end
  end
end
