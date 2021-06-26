# frozen_string_literal: true

require 'fugit'
require 'cloudtasker/worker_wrapper'

module Cloudtasker
  module Cron
    # Manage cron schedules
    class Schedule
      attr_accessor :id, :cron, :worker, :task_id, :job_id, :queue, :args

      #
      # Return the redis client.
      #
      # @return [Cloudtasker::RedisClient] The cloudtasker redis client.
      #
      def self.redis
        @redis ||= RedisClient.new
      end

      #
      # Return a namespaced key.
      #
      # @param [String, Symbol, nil] val The key to namespace
      #
      # @return [String] The namespaced key.
      #
      def self.key(val = nil)
        [to_s.underscore, val].compact.map(&:to_s).join('/')
      end

      #
      # Return all schedules
      #
      # @return [Array<Cloudtasker::Batch::Schedule>] The list of stored schedules.
      #
      def self.all
        if redis.exists?(key)
          # Use Schedule Set if available
          redis.smembers(key).map { |id| find(id) }
        else
          # Fallback to redis key matching and migrate schedules
          # to use Schedule Set instead.
          redis.search(key('*')).map do |gid|
            schedule_id = gid.sub(key(''), '')
            redis.sadd(key, schedule_id)
            find(schedule_id)
          end
        end
      end

      #
      # Synchronize list of cron schedules from a Hash. Schedules
      # not listed in this hash will be removed.
      #
      # @example
      #   Cloudtasker::Cron::Schedule.load_from_hash!(
      #     my_job: { cron: '0 0 * * *', worker: 'MyWorker' }
      #     my_other_job: { cron: '0 10 * * *', worker: 'MyOtherWorker' }
      #   )
      #
      def self.load_from_hash!(hash)
        schedules = hash.map do |id, config|
          schedule_config = JSON.parse(config.to_json, symbolize_names: true).merge(id: id.to_s)
          create(schedule_config)
        end

        # Remove existing schedules which are not part of the list
        all.reject { |e| schedules.include?(e) }.each { |e| delete(e.id) }
      end

      #
      # Create a new cron schedule (or update an existing one).
      #
      # @param [Hash] **opts Init opts. See initialize
      #
      # @return [Cloudtasker::Cron::Schedule] The schedule instance.
      #
      def self.create(**opts)
        redis.with_lock(key(opts[:id])) do
          config = find(opts[:id]).to_h.merge(opts)
          new(config).tap(&:save)
        end
      end

      #
      # Return a saved cron schedule.
      #
      # @param [String] id The schedule id.
      #
      # @return [Cloudtasker::Cron::Schedule] The schedule instance.
      #
      def self.find(id)
        return nil unless (schedule_config = redis.fetch(key(id)))

        new(**schedule_config)
      end

      #
      # Delete a schedule by id.
      #
      # @param [String] id The schedule id.
      #
      def self.delete(id)
        redis.with_lock(key(id)) do
          schedule = find(id)
          return false unless schedule

          # Delete task and stored schedule
          CloudTask.delete(schedule.task_id) if schedule.task_id
          redis.srem(key, schedule.id)
          redis.del(schedule.gid)
        end
      end

      #
      # Build a new instance of the class.
      #
      # @param [String] id The schedule id.
      # @param [String] cron The cron expression.
      # @param [Class] worker The worker class to run.
      # @param [Array<any>] args The worker arguments.
      # @param [String] queue The queue to use for the cron job.
      # @param [String] task_id The ID of the actual backend task.
      # @param [String] job_id The ID of the Cloudtasker worker.
      #
      def initialize(id:, cron:, worker:, **opts)
        @id = id
        @cron = cron
        @worker = worker
        @args = opts[:args]
        @queue = opts[:queue]
        @task_id = opts[:task_id]
        @job_id = opts[:job_id]
      end

      #
      # Return the redis client.
      #
      # @return [Cloudtasker::RedisClient] The cloudtasker redis client.
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
        self.class.key(id)
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
          worker: worker,
          args: args,
          queue: queue
        }
      end

      #
      # Return a hash with all the schedule attributes.
      #
      # @return [Hash] The attributes hash.
      #
      def to_h
        to_config.merge(
          task_id: task_id,
          job_id: job_id
        )
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
        WorkerWrapper.new(worker_name: worker, job_args: args, job_queue: queue)
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
      # @param [Hash] opts The attributes to edit.
      #
      def assign_attributes(opts)
        opts
          .select { |k, _| instance_variables.include?("@#{k}".to_sym) }
          .each { |k, v| instance_variable_set("@#{k}", v) }
      end

      #
      # Edit the object attributes and save the object in Redis.
      #
      # @param [Hash] opts The attributes to edit.
      #
      def update(opts)
        assign_attributes(opts)
        save
      end

      #
      # Save the object in Redis. If the configuration was changed
      # then any existing cloud task is removed and a task is recreated.
      #
      def save(update_task: true)
        return false unless valid?

        # Save schedule
        config_was_changed = config_changed?
        redis.sadd(self.class.key, id)
        redis.write(gid, to_h)

        # Stop there if backend does not need update
        return true unless update_task && (config_was_changed || !task_id || !CloudTask.find(task_id))

        # Update backend
        persist_cloud_task
      end

      private

      #
      # Update the task in backend.
      #
      def persist_cloud_task
        # Delete previous instance
        CloudTask.delete(task_id) if task_id

        # Schedule worker
        Job.new(worker_instance).set(schedule_id: id).schedule!
      end
    end
  end
end
