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
        # Return the worker configuration options.
        #
        # @return [Hash] The worker configuration options.
        #
        def options
          job.options
        end

        #
        # Return the strategy to use by default. Can be overriden in each lock.
        #
        # @return [Cloudtasker::UniqueJob::ConflictStrategy::BaseStrategy] The strategy to use by default.
        #
        def default_conflict_strategy
          ConflictStrategy::Reject
        end

        #
        # Return the conflict strategy to use on conflict
        #
        # @return [Cloudtasker::UniqueJob::ConflictStrategy::BaseStrategy] The instantiated strategy.
        #
        def conflict_instance
          @conflict_instance ||=
            begin
              # Infer lock class and get instance
              strategy_name = options[:on_conflict]
              strategy_klass = ConflictStrategy.const_get(strategy_name.to_s.split('_').collect(&:capitalize).join)
              strategy_klass.new(job)
            rescue NameError
              default_conflict_strategy.new(job)
            end
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
