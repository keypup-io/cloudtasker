# frozen_string_literal: true

module Cloudtasker
  module Batch
    # Handle batch management
    class Job
      attr_reader :worker

      # Key Namespace used for object saved under this class
      SUB_NAMESPACE = 'job'

      #
      # Return the cloudtasker redis client
      #
      # @return [Class] The redis client.
      #
      def self.redis
        RedisClient
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
        payload = redis.fetch(key(worker_id))
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
        worker.batch = new(worker)
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
      # @return [Class] The redis client.
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
        key(batch_id)
      end

      #
      # Return the key under which the batch state is stored.
      #
      # @return [String] The batch state namespaced id.
      #
      def batch_state_gid
        [batch_gid, 'state'].join('/')
      end

      #
      # The list of jobs in the batch
      #
      # @return [Array<Cloudtasker::Worker>] The jobs to enqueue at the end of the batch.
      #
      def jobs
        @jobs ||= []
      end

      #
      # Return the batch state
      #
      # @return [Hash] The state  of each child worker.
      #
      def batch_state
        redis.fetch(batch_state_gid)
      end

      #
      # Add a worker to the batch
      #
      # @param [Class] worker_klass The worker class.
      # @param [Array<any>] *args The worker arguments.
      #
      # @return [Array<Cloudtasker::Worker>] The updated list of jobs.
      #
      def add(worker_klass, *args)
        jobs << worker_klass.new(
          job_args: args,
          job_meta: { key(:parent_id) => batch_id }
        )
      end

      #
      # Save the batch.
      #
      def save
        # Save serialized version of the worker. This is required to
        # be able to invoke callback methods in the context of
        # the worker (= instantiated worker) when child workers
        # complete (success or failure).
        redis.write(batch_gid, worker.to_h)

        # Save list of child workers
        redis.write(batch_state_gid, jobs.map { |e| [e.job_id, 'scheduled'] }.to_h)
      end

      #
      # Update the batch state.
      #
      # @param [String] job_id The batch id.
      # @param [String] status The status of the sub-batch.
      #
      # @return [<Type>] <description>
      #
      def update_state(batch_id, status)
        redis.with_lock(batch_state_gid) do
          state = batch_state
          state[batch_id.to_sym] = status.to_s if state.key?(batch_id.to_sym)
          redis.write(batch_state_gid, state)
        end
      end

      #
      # Return true if all the child workers have completed.
      #
      # @return [<Type>] <description>
      #
      def complete?
        redis.with_lock(batch_state_gid) do
          state = redis.fetch(batch_state_gid)
          return true unless state

          # Check that all children are complete
          state.values.all? { |e| e == 'completed' }
        end
      end

      #
      # Run worker callback in a controlled environment to
      # avoid interruption of the callback flow.
      #
      # @param [String, Symbol] callback The callback to run.
      # @param [Array<any>] *args The callback arguments.
      #
      # @return [any] The callback return value
      #
      def run_worker_callback(callback, *args)
        worker.try(callback, *args)
      rescue StandardError => e
        Cloudtasker.logger.error("Error running callback #{callback}: #{e}")
        Cloudtasker.logger.error(e.backtrace.join("\n"))
        nil
      end

      #
      # Callback invoked when the batch is complete
      #
      def on_complete
        run_worker_callback(:on_batch_complete)

        # Propagate event
        parent_batch&.on_child_complete(self)
      ensure
        # The batch tree is complete. Cleanup the tree.
        cleanup unless parent_batch
      end

      #
      # Callback invoked when a direct child batch is complete.
      #
      # @param [Cloudtasker::Batch::Job] child_batch The completed child batch.
      #
      def on_child_complete(child_batch)
        # Update batch state
        update_state(child_batch.batch_id, :completed)

        # Notify the worker that a direct batch child worker has completed
        run_worker_callback(:on_child_complete, child_batch.worker)

        # Notify the parent batch that we are done with this batch
        on_complete if complete?
      end

      #
      # Callback invoked when any batch in the tree gets completed.
      #
      # @param [Cloudtasker::Batch::Job] child_batch The completed child batch.
      #
      def on_batch_node_complete(child_batch)
        # Notify the worker that a batch node worker has completed
        run_worker_callback(:on_batch_node_complete, child_batch.worker)

        # Notify the parent batch that a node is complete
        parent_batch&.on_batch_node_complete(child_batch)
      end

      #
      # Remove all batch and sub-batch keys from Redis.
      #
      def cleanup
        # Capture batch state
        state = batch_state

        # Delete child batches recursively
        state.to_h.keys.each { |id| self.class.find(id)&.cleanup }

        # Delete batch redis entries
        redis.del(batch_gid)
        redis.del(batch_state_gid)
      end

      #
      # Calculate the progress of the batch.
      #
      # @return [Cloudtasker::Batch::BatchProgress] The batch progress.
      #
      def progress
        # Capture batch state
        state = batch_state

        # Sum batch progress of current batch and all sub-batches
        state.to_h.reduce(BatchProgress.new(state)) do |memo, (child_id, child_status)|
          memo + (self.class.find(child_id)&.progress || BatchProgress.new(child_id => child_status))
        end
      end

      #
      # Save the batch and enqueue all child workers attached to it.
      #
      # @return [Array<Cloudtasker::CloudTask>] The Google Task responses
      #
      def setup
        return true if jobs.empty?

        # Save batch
        save

        # Enqueue all child workers
        jobs.map(&:schedule)
      end

      #
      # Post-perform logic. The parent batch is notified if the job is complete.
      #
      def complete
        return true if reenqueued? || jobs.any?

        # Notify the parent batch that a child is complete
        on_complete if complete?

        # Notify the parent that a batch node has completed
        parent_batch&.on_batch_node_complete(self)
      end

      #
      # Execute the batch.
      #
      def execute
        # Update parent batch state
        parent_batch&.update_state(batch_id, :processing)

        # Perform job
        yield

        # Save batch (if child worker has been enqueued)
        setup

        # Complete batch
        complete
      end
    end
  end
end
