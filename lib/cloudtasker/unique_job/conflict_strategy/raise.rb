# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    module ConflictStrategy
      # This strategy raises an error on conflict, both on client and server side.
      class Raise < BaseStrategy
        RESCHEDULE_DELAY = 5 # seconds

        # Raise a Cloudtasker::UniqueJob::LockError
        def on_schedule
          raise_lock_error
        end

        # Raise a Cloudtasker::UniqueJob::LockError
        def on_execute
          raise_lock_error
        end

        private

        def raise_lock_error
          raise(UniqueJob::LockError, id: job.id, unique_id: job.unique_id)
        end
      end
    end
  end
end
