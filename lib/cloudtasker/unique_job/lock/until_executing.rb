# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    module Lock
      # Conflict if any other job with the same args is scheduled
      # while the first job is pending.
      class UntilExecuting < BaseLock
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
        # Release the lock and perform the job.
        #
        def execute
          job.unlock!
          yield
        end
      end
    end
  end
end
