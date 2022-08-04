# frozen_string_literal: true

require 'fugit'

module Cloudtasker
  module Cron
    # Manage cron jobs
    class Job
      attr_reader :worker

      #
      # Build a new instance of the class
      #
      # @param [Cloudtasker::Worker] worker The cloudtasker worker
      #
      def initialize(worker)
        @worker = worker
      end

      #
      # Return a namespaced key
      #
      # @param [String, Symbol] val The key to namespace
      #
      # @return [String] The namespaced key.
      #
      def key(val)
        return nil if val.nil?

        [self.class.to_s.underscore, val.to_s].join('/')
      end

      #
      # Add cron metadata to the worker.
      #
      # @param [String, Symbol] name The name of the cron task.
      # @param [String] cron The cron expression.
      #
      # @return [Cloudtasker::Cron::Job] self.
      #
      def set(schedule_id:)
        worker.job_meta.set(key(:schedule_id), schedule_id.to_s)
        self
      end

      #
      # Return the worker id.
      #
      # @return [String] The worker id.
      #
      def job_id
        worker.job_id
      end

      #
      # Return the namespaced worker id.
      #
      # @return [String] The worker namespaced id.
      #
      def job_gid
        key(job_id)
      end

      #
      # Return the cron schedule id.
      #
      # @return [String] The schedule id.
      #
      def schedule_id
        @schedule_id ||= worker.job_meta.get(key(:schedule_id))
      end

      #
      # Return true if the worker is tagged as a cron job.
      #
      # @return [Boolean] True if the worker relates to a cron schedule.
      #
      def cron_job?
        cron_schedule
      end

      #
      # Return true if the worker is currently processing (includes retries).
      #
      # @return [Boolean] True f the worker is processing.
      #
      def retry_instance?
        cron_job? && state
      end

      #
      # Return the job processing state.
      #
      # @return [String, nil] The processing state.
      #
      def state
        redis.get(job_gid)&.to_sym
      end

      #
      # Return the cloudtasker redis client
      #
      # @return [Cloudtasker::RedisClient] The cloudtasker redis client..
      #
      def redis
        @redis ||= RedisClient.new
      end

      #
      # Return the cron schedule to use for the job.
      #
      # @return [Fugit::Cron] The cron schedule.
      #
      def cron_schedule
        return nil unless schedule_id

        @cron_schedule ||= Cron::Schedule.find(schedule_id)
      end

      #
      # Return the time this cron instance is expected to run at.
      #
      # @return [Time] The current cron instance time.
      #
      def current_time
        @current_time ||=
          begin
            Time.parse(worker.job_meta.get(key(:time_at)).to_s)
          rescue ArgumentError
            Time.try(:current) || Time.now
          end
      end

      #
      # Return the Time when the job should run next.
      #
      # @return [EtOrbi::EoTime] The time the job should run next.
      #
      def next_time
        @next_time ||= cron_schedule&.next_time(current_time)
      end

      #
      # Return true if the cron job is the one we are expecting. This method
      # is used to ensure that jobs related to outdated cron schedules do not
      # get processed.
      #
      # @return [Boolean] True if the cron job is expected.
      #
      def expected_instance?
        retry_instance? || cron_schedule.job_id == job_id
      end

      #
      # Store the cron job instance state.
      #
      # @param [String, Symbol] state The worker state.
      #
      def flag(state)
        state.to_sym == :done ? redis.del(job_gid) : redis.set(job_gid, state.to_s)
      end

      #
      # Schedule the next cron instance.
      #
      # The task only gets scheduled the first time a worker runs for a
      # given cron instance (Typically a cron worker failing and retrying will
      # not lead to a new task getting scheduled).
      #
      def schedule!
        return false unless cron_schedule

        # Configure next cron worker
        next_worker = worker.new_instance.tap { |e| e.job_meta.set(key(:time_at), next_time.iso8601) }

        # Schedule next worker
        task = next_worker.schedule(time_at: next_time)
        cron_schedule.update(task_id: task.id, job_id: next_worker.job_id)
      end

      #
      # Execute the (cron) job. This method is invoked by the cron middleware.
      #
      def execute
        # Execute the job immediately if this worker is not flagged as a cron job.
        return yield unless cron_job?

        # Abort and reject job if this cron instance is not expected.
        return true unless expected_instance?

        # Flag the cron instance as processing.
        flag(:processing)

        # Execute the cron instance
        yield

        # Flag the cron instance as done
        flag(:done)

        # Schedule the next instance of the job
        schedule! unless retry_instance?
      end
    end
  end
end
