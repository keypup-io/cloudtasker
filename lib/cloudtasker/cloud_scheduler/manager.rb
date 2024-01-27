# frozen_string_literal: true

require 'google/cloud/scheduler/v1'
require 'google/cloud/scheduler'

module Cloudtasker
  module CloudScheduler
    # Manage the synchronization of jobs between the
    # local configuration and the remote scheduler.
    class Manager
      #
      # Synchronize the local configuration with the remote scheduler.
      #
      # @param [String] file The path to the schedule configuration file.
      #
      def self.synchronize!(file)
        config = YAML.load_file(file)
        jobs = Job.load_from_hash!(config)

        new(jobs).synchronize!
      end

      attr_reader :jobs

      #
      # Build a new instance of the class.
      #
      # @param [Array<Cloudtasker::CloudScheduler::Job>] jobs The list of jobs to synchronize.
      #
      def initialize(jobs)
        @jobs = jobs
      end

      #
      # Synchronize the local configuration with the remote scheduler.
      #
      # @return [nil]
      #
      def synchronize!
        new_jobs.map(&:create!)
        stale_jobs.map(&:update!)
        deleted_jobs.map { |job| client.delete_job(name: job) }

        nil
      end

      private

      #
      # Return all jobs from the remote scheduler.
      #
      # @return [Array<String>] The list of job names.
      #
      def remote_jobs
        @remote_jobs ||= client.list_jobs(parent: parent)
                               .response
                               .jobs
                               .map(&:name)
                               .select do |job|
          job.start_with?(job_prefix)
        end
      end

      #
      # Return all jobs that are not yet created in the remote scheduler.
      #
      # @return [Array<Cloudtasker::CloudScheduler::Job>] The list of jobs.
      #
      def new_jobs
        jobs.reject do |job|
          remote_jobs.include?(job.remote_name)
        end
      end

      #
      # Return all jobs that are present in both local config and remote scheduler.
      #
      # @return [Array<Cloudtasker::CloudScheduler::Job>] The list of jobs.
      #
      def stale_jobs
        jobs.select do |job|
          remote_jobs.include?(job.remote_name)
        end
      end

      #
      # Return all jobs that are present in the remote scheduler but not in the local config.
      #
      # @return [Array<String>] The list of job names.
      #
      def deleted_jobs
        remote_jobs - jobs.map(&:remote_name)
      end

      #
      # Prefix for all jobs that includes the parent path and the queue prefix.
      #
      # @return [String] The job prefix.
      #
      def job_prefix
        "#{parent}/jobs/#{config.gcp_queue_prefix}--"
      end

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
