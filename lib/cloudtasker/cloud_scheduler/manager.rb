# frozen_string_literal: true

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

      def remote_jobs
        @remote_jobs ||= client.list_jobs(parent: parent)
                               .response
                               .jobs
                               .map(&:name)
                               .select do |job|
          job.start_with?(job_prefix)
        end
      end

      def new_jobs
        jobs.reject do |job|
          remote_jobs.include?(job.remote_name)
        end
      end

      def stale_jobs
        jobs.select do |job|
          remote_jobs.include?(job.remote_name)
        end
      end

      def deleted_jobs
        remote_jobs - jobs.map(&:remote_name)
      end

      def job_prefix
        "#{parent}/jobs/#{config.gcp_queue_prefix}--"
      end

      def parent
        @parent ||= client.location_path(project: config.gcp_project_id, location: config.gcp_location_id)
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
