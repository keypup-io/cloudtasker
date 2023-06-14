# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    module Lock
      # Conflict if any other job with the same args is scheduled or moved to execution
      # while the first job is pending or executing.
      class UntilExecuted < BaseLock
        #
        # Acquire a lock for the job and trigger a conflict
        # if the lock could not be acquired.
        #
        def schedule(&block)
          job.lock!
          yield
        rescue LockError
          conflict_instance.on_schedule(&block)
        end

        #
        # Acquire a lock for the job and trigger a conflict
        # if the lock could not be acquired.
        #
        def execute(&block)
          job.lock!
          yield
        rescue LockError
          conflict_instance.on_execute(&block)
        ensure
          # Unlock the job on any error to avoid deadlocks.
          job.unlock!
        end
      end
    end
  end
end
