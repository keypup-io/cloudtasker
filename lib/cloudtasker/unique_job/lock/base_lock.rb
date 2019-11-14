# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    module Lock
      # Base behaviour for locks
      class BaseLock
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
        # Lock logic invoked when a job is scheduled (client middleware).
        #
        def schedule
          yield
        end

        #
        # Lock logic invoked when a job is executed (server middleware).
        #
        def execute
          yield
        end
      end
    end
  end
end
