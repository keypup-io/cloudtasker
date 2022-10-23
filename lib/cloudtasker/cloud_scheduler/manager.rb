require "google/cloud/scheduler"
module Cloudtasker
  module CloudScheduler
    class Manager
      class << self
        def synchronize!(file)
          new(YAML.load_file(file)).synchronize!
        end
      end

      attr_reader :client, :cron_config

      def initialize(cron_config = {})
        @client = Google::Cloud::Scheduler.cloud_scheduler
        @cron_config = cron_config
      end

      def synchronize!
        remote_list_names = remote_list.map(&:name).select{|x| x.start_with?(job_prefix) }
        puts "Creating/updating jobs"
        if local_list.present?
          local_list.each do |job|
            if job[:name].in?(remote_list_names)
              client.update_job(job: job)
            else
              puts "Creating #{job[:name]}"
              client.create_job(parent: parent, job: job)
            end
          end
        end

        local_list_names = local_list.map{|x| x[:name] }
        delete_jobs = (remote_list_names - local_list_names)

        if delete_jobs.present?
          puts "Deleting jobs"
          delete_jobs.each do |name|
            puts "Deleting #{name}"
            client.delete_job(name: name)
          end
        end

        true
      end

      private

      def local_list
        cron_config.map do |name, job_config|
          build_job(name, job_config)
        end
      end

      def remote_list
        client.list_jobs(parent: parent).response.jobs
      end


      def job_prefix
        "#{parent}/jobs/#{config.gcp_queue_prefix}--"
      end

      def job_name(name)
        "#{job_prefix}#{name}"
      end

      def build_job(name, job_config)
        request = Cloudtasker::WorkerHandler.new(job_config["worker"].constantize.new).task_payload[:http_request]
        {
          name: job_name(name),
          schedule: job_config["cron"],
          time_zone: job_config["time_zone"] || 'UTC',
          http_target: {
            uri: request[:url],
            http_method: request[:http_method],
            headers: request[:headers],
            body: request[:body]
          }
        }
      end

      def parent
        client.location_path(project: config.gcp_project_id, location: config.gcp_location_id)
      end

      #
      # Return the cloudtasker configuration. See Cloudtasker#configure.
      #
      # @return [Cloudtasker::Config] The library configuration.
      #
      def config
        Cloudtasker.config
      end
    end
  end
end
