# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    module ConflictStrategy
      # Base behaviour for conflict strategies
      class BaseStrategy
        attr_reader :job

        #
        # Build a new instance of the class.
        #
        # @param [Cloudtasker::UniqueJob::Job] job The UniqueJob job
        #
        def initialize(job)
          @job = job
        end

        #
        # Handling logic to perform when a conflict occurs while
        # scheduling a job.
        #
        def on_schedule
          true
        end

        #
        # Handling logic to perform when a conflict occurs while
        # executing a job.
        #
        def on_execute
          true
        end
      end
    end
  end
end
