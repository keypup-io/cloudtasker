# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    module Lock
      # Conflict if any other job with the same args is scheduled or moved to execution
      # while the first job is pending or executing. Unlocks only on successful completion
      # or when a DeadWorkerError is raised.
      class UntilCompleted < BaseLock
        #
        # Acquire a lock for the job and trigger a conflict
        # if the lock could not be acquired.
        #
        def schedule(&block)
          job.lock_for_scheduling!(&block)
        rescue LockError
          conflict_instance.on_schedule(&block)
        rescue StandardError
          # Unlock the job if any error arises during scheduling
          job.unlock!
          raise
        end

        #
        # Acquire a lock for the job and trigger a conflict
        # if the lock could not be acquired.
        #
        def execute(&block)
          job.lock!
          yield
          # Unlock on successful completion
          job.unlock!
        rescue LockError
          conflict_instance.on_execute(&block)
        rescue Cloudtasker::DeadWorkerError
          # Unlock when DeadWorkerError is raised
          job.unlock!
          raise
        end
      end
    end
  end
end
