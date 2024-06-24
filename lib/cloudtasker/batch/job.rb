# frozen_string_literal: true

module Cloudtasker
  module Batch
    # Handle batch management
    class Job
      attr_reader :worker

      # Key Namespace used for object saved under this class
      JOBS_NAMESPACE = 'jobs'
      STATES_NAMESPACE = 'states'

      # List of sub-job statuses taken into account when evaluating
      # if the batch is complete.
      #
      # Batch jobs go through the following states:
      # - scheduled: the parent batch has enqueued a worker for the child job
      # - processing: the child job is running
      # - completed: the child job has completed successfully
      # - errored: the child job has encountered an error and must retry
      # - dead: the child job has exceeded its max number of retries
      #
      # The 'dead' status is considered to be a completion status as it
      # means that the job will never succeed. There is no point in blocking
      # the batch forever so we proceed forward eventually.
      #
      BATCH_STATUSES = %w[scheduled processing completed errored dead all].freeze
      COMPLETION_STATUSES = %w[completed dead].freeze

      # These callbacks do not need to raise errors on their own
      # because the jobs will be either retried or dropped
      IGNORED_ERRORED_CALLBACKS = %i[on_child_error on_child_dead].freeze

      # The maximum number of seconds to wait for a batch state lock
      # to be acquired.
      BATCH_MAX_LOCK_WAIT = 60

      #
      # Return the cloudtasker redis client
      #
      # @return [Cloudtasker::RedisClient] The cloudtasker redis client..
      #
      def self.redis
        @redis ||= RedisClient.new
      end

      #
      # Find a batch by id.
      #
      # @param [String] batch_id The batch id.
      #
      # @return [Cloudtasker::Batch::Job, nil] The batch.
      #
      def self.find(worker_id)
        return nil unless worker_id

        # Retrieve related worker
        payload = redis.fetch(key("#{JOBS_NAMESPACE}/#{worker_id}"))
        worker = Cloudtasker::Worker.from_hash(payload)
        return nil unless worker

        # Build batch job
        self.for(worker)
      end

      #
      # Return a namespaced key.
      #
      # @param [String, Symbol] val The key to namespace
      #
      # @return [String] The namespaced key.
      #
      def self.key(val)
        return nil if val.nil?

        [to_s.underscore, val.to_s].join('/')
      end

      #
      # Attach a batch to a worker
      #
      # @param [Cloudtasker::Worker] worker The worker on which the batch must be attached.
      #
      # @return [Cloudtasker::Batch::Job] The attached batch.
      #
      def self.for(worker)
        # Load extension if not loaded already on the worker class
        worker.class.include(Extension::Worker) unless worker.class <= Extension::Worker

        # Add batch and parent batch to worker
        worker.batch = new(worker)
        worker.parent_batch = worker.batch.parent_batch

        # Return the batch
        worker.batch
      end

      #
      # Build a new instance of the class.
      #
      # @param [Cloudtasker::Worker] worker The batch worker
      #
      def initialize(worker)
        @worker = worker
      end

      #
      # Return true if the worker has been re-enqueued.
      # Post-process logic should be skipped for re-enqueued jobs.
      #
      # @return [Boolean] Return true if the job was reequeued.
      #
      def reenqueued?
        worker.job_reenqueued
      end

      #
      # Return the cloudtasker redis client
      #
      # @return [Cloudtasker::RedisClient] The cloudtasker redis client..
      #
      def redis
        self.class.redis
      end

      #
      # Equality operator.
      #
      # @param [Any] other The object to compare.
      #
      # @return [Boolean] True if the object is equal.
      #
      def ==(other)
        other.is_a?(self.class) && other.batch_id == batch_id
      end

      #
      # Return a namespaced key.
      #
      # @param [String, Symbol] val The key to namespace
      #
      # @return [String] The namespaced key.
      #
      def key(val)
        self.class.key(val)
      end

      #
      # Return the parent batch, if any.
      #
      # @return [Cloudtasker::Batch::Job, nil] The parent batch.
      #
      def parent_batch
        return nil unless (parent_id = worker.job_meta.get(key(:parent_id)))

        @parent_batch ||= self.class.find(parent_id)
      end

      #
      # Return the worker id.
      #
      # @return [String] The worker id.
      #
      def batch_id
        worker&.job_id
      end

      #
      # Return the namespaced worker id.
      #
      # @return [String] The worker namespaced id.
      #
      def batch_gid
        key("#{JOBS_NAMESPACE}/#{batch_id}")
      end

      #
      # Return the key under which the batch state is stored.
      #
      # @return [String] The batch state namespaced id.
      #
      def batch_state_gid
        key("#{STATES_NAMESPACE}/#{batch_id}")
      end

      #
      # Return the key under which the batch progress is stored
      # for a specific state.
      #
      # @return [String] The batch progress state namespaced id.
      #
      def batch_state_count_gid(state)
        "#{batch_state_gid}/state_count/#{state}"
      end

      #
      # Return the number of jobs in a given state
      #
      # @return [String] The batch progress state namespaced id.
      #
      def batch_state_count(state)
        redis.get(batch_state_count_gid(state)).to_i
      end

      #
      # The list of jobs to be enqueued in the batch
      #
      # @return [Array<Cloudtasker::Worker>] The jobs to enqueue at the end of the batch.
      #
      def pending_jobs
        @pending_jobs ||= []
      end

      #
      # The list of jobs that have been enqueued as part of the batch
      #
      # @return [Array<Cloudtasker::Worker>] The jobs enqueued as part of the batch.
      #
      def enqueued_jobs
        @enqueued_jobs ||= []
      end

      #
      # Return the batch state
      #
      # @return [Hash] The state  of each child worker.
      #
      def batch_state
        migrate_batch_state_to_redis_hash

        redis.hgetall(batch_state_gid)
      end

      #
      # Add a worker to the batch
      #
      # @param [Class] worker_klass The worker class.
      # @param [Array<any>] *args The worker arguments.
      #
      # @return [Array<Cloudtasker::Worker>] The updated list of pending jobs.
      #
      def add(worker_klass, *args)
        add_to_queue(worker.job_queue, worker_klass, *args)
      end

      #
      # Add a worker to the batch using a specific queue.
      #
      # @param [String, Symbol] queue The name of the queue
      # @param [Class] worker_klass The worker class.
      # @param [Array<any>] *args The worker arguments.
      #
      # @return [Array<Cloudtasker::Worker>] The updated list of pending jobs.
      #
      def add_to_queue(queue, worker_klass, *args)
        pending_jobs << worker_klass.new(
          job_args: args,
          job_meta: { key(:parent_id) => batch_id },
          job_queue: queue
        )
      end

      #
      # This method migrates the batch state to be a Redis hash instead
      # of a hash stored in a string key.
      #
      def migrate_batch_state_to_redis_hash
        return unless redis.type(batch_state_gid) == 'string'

        # Migrate batch state to Redis hash if it is still using a legacy string key
        # We acquire a lock then check again
        redis.with_lock(batch_state_gid, max_wait: BATCH_MAX_LOCK_WAIT) do
          if redis.type(batch_state_gid) == 'string'
            state = redis.fetch(batch_state_gid)
            redis.del(batch_state_gid)
            redis.hset(batch_state_gid, state) if state.any?
          end
        end
      end

      #
      # This method initializes the batch job counters if not set already
      #
      def migrate_progress_stats_to_redis_counters
        # Abort if counters have already been set. The 'all' counter acts as a feature flag.
        return if redis.exists?(batch_state_count_gid('all'))

        # Get all job states
        values = batch_state.values

        # Count by value
        redis.multi do |m|
          # Per status
          values.tally.each do |k, v|
            m.set(batch_state_count_gid(k), v)
          end

          # All counter
          m.set(batch_state_count_gid('all'), values.size)
        end
      end

      #
      # Save serialized version of the worker.
      #
      # This is required to be able to invoke callback methods in the
      # context of the worker (= instantiated worker) when child workers
      # complete (success or failure).
      #
      def save
        redis.write(batch_gid, worker.to_h)
      end

      #
      # Update the batch state.
      #
      # @param [String] job_id The batch id.
      # @param [String] status The status of the sub-batch.
      #
      def update_state(batch_id, status)
        migrate_batch_state_to_redis_hash

        # Get current status
        current_status = redis.hget(batch_state_gid, batch_id)
        return if current_status == status.to_s

        # Update the batch state batch_id entry with the new status
        # and update counters
        redis.multi do |m|
          m.hset(batch_state_gid, batch_id, status)
          m.decr(batch_state_count_gid(current_status))
          m.incr(batch_state_count_gid(status))
        end
      end

      #
      # Return true if all the child workers have completed.
      #
      # @return [Boolean] True if the batch is complete.
      #
      def complete?
        migrate_batch_state_to_redis_hash

        # Check that all child jobs have completed
        redis.hvals(batch_state_gid).all? { |e| COMPLETION_STATUSES.include?(e) }
      end

      #
      # Run worker callback. The error and dead callbacks get
      # silenced should they raise an error.
      #
      # @param [String, Symbol] callback The callback to run.
      # @param [Array<any>] *args The callback arguments.
      #
      # @return [any] The callback return value
      #
      def run_worker_callback(callback, *args)
        worker.try(callback, *args).tap do
          # Enqueue pending jobs if batch was expanded in callback
          # A completed batch cannot receive additional jobs
          schedule_pending_jobs if callback.to_sym != :on_batch_complete

          # Schedule pending jobs on parent if batch was expanded
          parent_batch&.schedule_pending_jobs
        end
      rescue StandardError => e
        # There is no point in retrying jobs due to failure callbacks failing
        # Only completion callbacks will trigger a re-run of the job because
        # these do matter for batch completion
        raise(e) unless IGNORED_ERRORED_CALLBACKS.include?(callback)

        # Log error instead
        worker.logger.error(e)
        worker.logger.error("Callback #{callback} failed to run. Skipping to preserve error flow.")
      end

      #
      # Callback invoked when the batch is complete
      #
      def on_complete(status = :completed)
        # Invoke worker callback
        run_worker_callback(:on_batch_complete) if status == :completed

        # Propagate event
        parent_batch&.on_child_complete(self, status)

        # The batch tree is complete. Cleanup the downstream tree.
        cleanup
      end

      #
      # Callback invoked when a direct child batch is complete.
      #
      # @param [Cloudtasker::Batch::Job] child_batch The completed child batch.
      #
      def on_child_complete(child_batch, status = :completed)
        # Update batch state
        update_state(child_batch.batch_id, status)

        # Notify the worker that a direct batch child worker has completed
        case status
        when :completed
          run_worker_callback(:on_child_complete, child_batch.worker)
        when :errored
          run_worker_callback(:on_child_error, child_batch.worker)
        when :dead
          run_worker_callback(:on_child_dead, child_batch.worker)
        end

        # Notify the parent batch that we are done with this batch
        on_complete if status != :errored && complete?
      end

      #
      # Callback invoked when any batch in the tree gets completed.
      #
      # @param [Cloudtasker::Batch::Job] child_batch The completed child batch.
      #
      def on_batch_node_complete(child_batch, status = :completed)
        return false unless status == :completed

        # Notify the worker that a batch node worker has completed
        run_worker_callback(:on_batch_node_complete, child_batch.worker)

        # Notify the parent batch that a node is complete
        parent_batch&.on_batch_node_complete(child_batch)
      end

      #
      # Remove all batch and sub-batch keys from Redis.
      #
      def cleanup
        migrate_batch_state_to_redis_hash

        # Delete child batches recursively
        redis.hkeys(batch_state_gid).each { |id| self.class.find(id)&.cleanup }

        # Delete batch redis entries
        redis.multi do |m|
          m.del(batch_gid)
          m.del(batch_state_gid)
          BATCH_STATUSES.each { |e| m.del(batch_state_count_gid(e)) }
        end
      end

      #
      # Calculate the progress of the batch.
      #
      # @param [Integer] depth The depth of calculation. Zero (default) means only immediate
      #   children will be taken into account.
      #
      # @return [Cloudtasker::Batch::BatchProgress] The batch progress.
      #
      def progress(depth: 0)
        depth = depth.to_i

        # Initialize counters from batch state. This is only applicable to running batches
        # that started before the counter-based progress was implemented/released.
        migrate_progress_stats_to_redis_counters

        # Return immediately if we do not need to go down the tree
        return BatchProgress.new([self]) if depth <= 0

        # Sum batch progress of current batch and sub-batches up to the specified
        # depth
        batch_state.to_h.reduce(BatchProgress.new([self])) do |memo, (child_id, _)|
          memo + (self.class.find(child_id)&.progress(depth: depth - 1) || BatchProgress.new)
        end
      end

      #
      # Schedule the child workers that were added to the batch
      #
      def schedule_pending_jobs
        ret_list = []

        while (j = pending_jobs.shift)
          # Schedule the job
          # Skip batch registration if the job was not actually scheduled
          # E.g. the job was evicted due to uniqueness requirements
          next unless j.schedule

          # Initialize the batch state unless the job has already started (and taken
          # hold of its own status)
          # The batch state is initialized only after the job is scheduled to avoid
          # having never-ending batches - which could occur if a batch was crashing
          # while enqueuing children due to a OOM error and since 'scheduled' is a
          # blocking status.
          redis.multi do |m|
            m.hsetnx(batch_state_gid, j.job_id, 'scheduled')
            m.incr(batch_state_count_gid('scheduled'))
            m.incr(batch_state_count_gid('all'))
          end

          # Flag job as enqueued
          ret_list << j
          enqueued_jobs << j
        end

        # Return the list of jobs just enqueued
        ret_list
      end

      #
      # Save the batch and enqueue all child workers attached to it.
      #
      def setup
        return true if pending_jobs.empty?

        # Save batch
        save

        # Schedule all child workers
        schedule_pending_jobs
      end

      #
      # Post-perform logic. The parent batch is notified if the job is complete.
      #
      def complete(status = :completed)
        return true if reenqueued?

        # Notify the parent batch that a child is complete
        on_complete(status) if complete?

        # Notify the parent that a batch node has completed
        parent_batch&.on_batch_node_complete(self, status)
      end

      #
      # Execute the batch.
      #
      def execute
        # Update parent batch state
        parent_batch&.update_state(batch_id, :processing)

        # Perform job
        yield

        # Setup batch
        # Only applicable if the batch has pending_jobs
        setup

        # Save parent batch if batch was expanded
        parent_batch&.schedule_pending_jobs

        # Complete batch
        complete(:completed)
      rescue DeadWorkerError => e
        complete(:dead)
        raise(e)
      rescue StandardError => e
        complete(:errored)
        raise(e)
      end
    end
  end
end
