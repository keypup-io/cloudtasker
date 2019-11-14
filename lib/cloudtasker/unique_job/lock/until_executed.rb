# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    module Lock
      # Conflict if any other job with the same args is scheduled or moved to execution
      # while the first job is pending or executing.
      class UntilExecuted < BaseLock
        def schedule
          job.lock!
          yield
          # rescue LockError
          #   conflict_strategy.on_schedule
        end

        def execute
          job.lock!
          yield
          job.unlock!
          # rescue LockError
          #   conflict_strategy.on_execute
        end
      end
    end
  end
end
