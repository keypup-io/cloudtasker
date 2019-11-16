# frozen_string_literal: true

require 'fugit'

module Cloudtasker
  module Cron
    # Manage cron schedules
    class Schedule
      attr_accessor :id, :cron, :worker, :task_id, :job_id

      #
      # Return the redis client.
      #
      # @return [Class] The redis client
      #
      def self.redis
        RedisClient
      end

      #
      # Create a new cron schedule (or update an existing one).
      #
      # @param [Hash] **opts Init opts. See initialize
      #
      # @return [Cloudtasker::Cron::Schedule] The schedule instance.
      #
      def self.create(**opts)
        config = find(opts[:id]).to_h.merge(opts)
        new(config).tap(&:save)
      end

      #
      # Return a saved cron schedule.
      #
      # @param [String] id The schedule id.
      #
      # @return [Cloudtasker::Cron::Schedule] The schedule instance.
      #
      def self.find(id)
        gid = [Config::KEY_NAMESPACE, id].join('/')
        return nil unless (schedule_config = redis.fetch(gid))

        new(schedule_config)
      end

      #
      # Destroy a schedule by id.
      #
      # @param [String] id The schedule id.
      #
      def self.delete(id)
        schedule = find(id)
        return false unless schedule

        # Delete task and stored schedule
        Task.delete(schedule.task_id) if schedule.task_id
        redis.del(schedule.gid)
      end

      #
      # Build a new instance of the class.
      #
      # @param [String] id The schedule id.
      # @param [String] cron The cron expression.
      # @param [Class] worker The worker class to run.
      # @param [String] task_id The ID of the actual backend task.
      # @param [String] job_id The ID of the Cloudtasker worker.
      #
      def initialize(id:, cron:, worker:, task_id: nil, job_id: nil)
        @id = id
        @cron = cron
        @worker = worker
        @task_id = task_id
        @job_id = job_id
      end

      #
      # Return the redis client.
      #
      # @return [Class] The redis client
      #
      def redis
        self.class.redis
      end

      #
      # Return the namespaced schedule id.
      #
      # @return [String] The namespaced schedule id.
      #
      def gid
        [Config::KEY_NAMESPACE, id].join('/')
      end

      #
      # Return true if the schedule is valid.
      #
      # @return [Boolean] True if the schedule is valid.
      #
      def valid?
        id && cron_schedule && worker
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

      #
      # Return true if the configuration of the schedule was
      # changed (cron expression or worker).
      #
      # @return [Boolean] True if the schedule config was changed.
      #
      def config_changed?
        self.class.find(id)&.to_config != to_config
      end

      #
      # RReturn true if the instance attributes were changed compared
      # to the schedule saved in Redis.
      #
      # @return [Boolean] True if the schedule was modified.
      #
      def changed?
        to_h != self.class.find(id).to_h
      end

      #
      # Return a hash describing the configuration of this schedule.
      #
      # @return [Hash] The config description hash.
      #
      def to_config
        {
          id: id,
          cron: cron,
          worker: worker
        }
      end

      #
      # Return a hash with all the schedule attributes.
      #
      # @return [Hash] The attributes hash.
      #
      def to_h
        {
          id: id,
          cron: cron,
          worker: worker,
          task_id: task_id,
          job_id: job_id
        }
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
      # Return the next time a job should run.
      #
      # @param [Time] time An optional reference in time (instead of Time.now)
      #
      # @return [EtOrbi::EoTime] The time the schedule job should run next.
      #
      def next_time(*args)
        cron_schedule.next_time(*args)
      end

      #
      # Buld edit the object attributes.
      #
      # @param [Hash] **opts The attributes to edit.
      #
      def assign_attributes(**opts)
        opts
          .select { |k, _| instance_variables.include?("@#{k}".to_sym) }
          .each { |k, v| instance_variable_set("@#{k}", v) }
      end

      #
      # Edit the object attributes and save the object in Redis.
      #
      # @param [Hash] **opts The attributes to edit.
      #
      def update(**opts)
        assign_attributes(opts)
        save
      end

      #
      # Save the object in Redis. If the configuration was changed
      # then any existing cloud task is removed and a task is recreated.
      #
      def save(update_task: true)
        return false unless valid? && changed?

        # Save schedule
        config_was_changed = config_changed?
        redis.write(gid, to_h)

        # Stop there if backend does not need update
        return true unless update_task && config_was_changed

        # Delete previous instance
        Task.delete(task_id) if task_id

        # Schedule worker
        worker_instance = Object.const_get(worker).new
        Job.new(worker_instance).set(schedule_id: id).schedule!
      end
    end
  end
end
