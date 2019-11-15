# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    module ConflictStrategy
      # This strategy reschedules the job on conflict. This strategy can only
      # be used with processing locks (e.g. while_executing).
      class Reschedule < BaseStrategy
        RESCHEDULE_DELAY = 5 # seconds

        #
        # A conflict on schedule means that this strategy is being used
        # with a lock scheduling strategy (e.g. until_executed) instead of a
        # processing strategy (e.g. while_executing). In this case we let the
        # scheduling happen as it does not make sense to reschedule in this context.
        #
        def on_schedule
          yield
        end

        #
        # Reschedule the job.
        #
        def on_execute
          job.worker.reenqueue(RESCHEDULE_DELAY)
        end
      end
    end
  end
end
