# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    module Lock
      # Conflict if any other job with the same args is moved to execution
      # while the first job is executing.
      class WhileExecuting < BaseLock
        #
        # Acquire a lock for the job and trigger a conflict
        # if the lock could not be acquired.
        #
        def execute
          job.lock!
          yield
          job.unlock!
        rescue LockError
          conflict_instance.on_execute { yield }
        end
      end
    end
  end
end
