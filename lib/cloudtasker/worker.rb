# frozen_string_literal: true

module Cloudtasker
  # Cloud Task based workers
  module Worker
    # Add class method to including class
    def self.included(base)
      base.extend(ClassMethods)
      base.attr_accessor :job_args, :job_id, :job_meta
    end

    # Module class methods
    module ClassMethods
      #
      # Set the worker runtime options.
      #
      # @param [Hash] opts The worker options
      #
      # @return [<Type>] <description>
      #
      def cloudtasker_options(opts = {})
        opt_list = opts&.map { |k, v| [k.to_s, v] } || [] # stringify
        @cloudtasker_options_hash = Hash[opt_list]
      end

      #
      # Return the worker runtime options.
      #
      # @return [Hash] The worker runtime options.
      #
      def cloudtasker_options_hash
        @cloudtasker_options_hash
      end

      #
      # Enqueue worker in the backgroundf.
      #
      # @param [Array<any>] *args List of worker arguments
      #
      # @return [Google::Cloud::Tasks::V2beta3::Task] The Google Task response
      #
      def perform_async(*args)
        perform_in(nil, *args)
      end

      #
      # Enqueue worker and delay processing.
      #
      # @param [Integer, nil] interval The delay in seconds.
      # @param [Array<any>] *args List of worker arguments.
      #
      # @return [Google::Cloud::Tasks::V2beta3::Task] The Google Task response
      #
      def perform_in(interval, *args)
        new(job_args: args).schedule(interval: interval)
      end

      #
      # Enqueue worker and delay processing.
      #
      # @param [Time, Integer] time_at The time at which the job should run.
      # @param [Array<any>] *args List of worker arguments
      #
      # @return [Google::Cloud::Tasks::V2beta3::Task] The Google Task response
      #
      def perform_at(time_at, *args)
        new(job_args: args).schedule(time_at: time_at)
      end
    end

    #
    # Build a new worker instance.
    #
    # @param [Array<any>] job_args The list of perform args.
    # @param [String] job_id A unique ID identifying this job.
    #
    def initialize(job_args: [], job_id: nil, job_meta: {})
      @job_args = job_args
      @job_id = job_id || SecureRandom.uuid
      @job_meta = job_meta || {}
    end

    #
    # Execute the worker by calling the `perform` with the args.
    #
    # @return [Any] The result of the perform.
    #
    def execute
      Cloudtasker.config.server_middleware.invoke(self) do
        perform(*job_args)
      end
    end

    #
    # Enqueue a worker, with or without delay.
    #
    # @param [Integer] interval The delay in seconds.
    #
    # @param [Time, Integer] interval The time at which the job should run
    #
    # @return [Google::Cloud::Tasks::V2beta3::Task] The Google Task response
    #
    def schedule(interval: nil, time_at: nil)
      Cloudtasker.config.client_middleware.invoke(self) do
        Task.new(self).schedule(interval: interval, time_at: time_at)
      end
    end

    #
    # Helper method used to re-enqueue the job. Re-enqueued
    # jobs keep the same job_id.
    #
    # This helper may be useful when jobs must pause activity due to external
    # factors such as when a third-party API is throttling the rate of API calls.
    #
    # @param [Integer] interval Delay to wait before processing the job again (in seconds).
    #
    # @return [Google::Cloud::Tasks::V2beta3::Task] The Google Task response
    #
    def reenqueue(interval)
      schedule(interval: interval)
    end

    #
    # Set meta information on the job. This may be used by middlewares
    # to store additional information on the job itself (e.g. a tracking ID).
    #
    # @param [String, Symbol] key The key of the meta info.
    # @param [Any] val The value of the meta info.
    #
    # @return [<Type>] <description>
    #
    def set_meta(key, val)
      job_meta[key.to_sym] = val
    end

    #
    # Retrieve meta information from the worker. This may be used by middlewares
    # to retrieve information on the job itself (e.g. a tracking ID).
    #
    # @param [String, Symbol] key The key of the meta info.
    #
    # @return [<Type>] <description>
    #
    def get_meta(key)
      job_meta[key.to_sym]
    end
  end
end
