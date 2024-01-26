# frozen_string_literal: true

require 'fugit'

module Cloudtasker
  module CloudScheduler
    # Error raised when a schedule is invalid
    class InvalidScheduleError < StandardError; end

    # Manage cron schedules
    class Schedule
      DEFAULT_TIME_ZONE = 'Etc/UTC'

      attr_accessor :id, :cron, :worker, :queue, :args, :time_zone

      #
      # Return all valid schedules while raising an error if any schedule is invalid.
      #
      # @return [Array<Cloudtasker::CloudScheduler::Schedule>] The list of valid schedules.
      #
      # @raise [RuntimeError] If any schedule is invalid.
      def self.load_from_hash!(hash)
        return [] if hash.blank?

        hash.map do |id, config|
          schedule = new(
            id: id.to_s,
            cron: config["cron"],
            worker: config["worker"],
            args: config["args"],
            queue: config["queue"],
            time_zone: config["time_zone"] || DEFAULT_TIME_ZONE
          )

          raise InvalidScheduleError, "Invalid schedule: #{schedule.id}" unless schedule.valid?

          schedule
        end
      end

      #
      # Build a new instance of the class.
      #
      # @param [String] id The schedule ID.
      # @param [String] cron The cron expression.
      # @param [Class] worker The worker class to run.
      # @param [Array<any>] args The worker arguments.
      # @param [String] queue The queue to use for the cron job.
      # @param [String] time_zone The time zone to use for the cron job.
      #
      def initialize(id:, cron:, worker:, **opts)
        @id = id
        @cron = cron
        @worker = worker
        @args = opts[:args]
        @queue = opts[:queue]
        @time_zone = opts[:time_zone]
      end

      #
      # Validate the schedule
      #
      # @return [Boolean] True if the schedule is valid, false otherwise.
      #
      def valid?
        id && cron_schedule && worker
      end

      #
      # Return the cron schedule to use for the job.
      #
      # @return [Fugit::Cron] The cron schedule.
      #
      def cron_schedule
        @cron_schedule ||= Fugit::Cron.parse(cron)
      end

      #
      # Return an instance of the underlying worker.
      #
      # @return [Cloudtasker::WorkerWrapper] The worker instance
      #
      def worker_instance
        @worker_instance ||= worker.safe_constantize.new(job_queue: queue, job_args: args)
      end

      #
      # Return an instance of the worker handler.
      #
      # @return [Cloudtasker::WorkerHandler] The worker handler.
      #
      def worker_handler
        @worker_handler ||= Cloudtasker::WorkerHandler.new(worker_instance)
      end
    end
  end
end
