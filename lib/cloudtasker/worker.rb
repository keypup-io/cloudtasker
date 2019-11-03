# frozen_string_literal: true

module Cloudtasker
  # Cloud Task based workers
  module Worker
    # Add class method to including class
    def self.included(base)
      base.extend(ClassMethods)
      base.attr_accessor :job_args, :job_id
    end

    # Module class methods
    module ClassMethods
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
      # @param [Array<any>] *args List of worker arguments
      #
      # @return [Google::Cloud::Tasks::V2beta3::Task] The Google Task response
      #
      def perform_in(interval, *args)
        Task.new(worker: self, job_args: args).schedule(interval: interval)
      end
    end

    #
    # Build a new worker instance.
    #
    # @param [Array<any>] job_args The list of perform args.
    # @param [Array<any>] job_id A unique ID identifying this job.
    #
    def initialize(job_args:, job_id:)
      @job_args = job_args
      @job_id = job_id
    end

    #
    # Execute the worker by calling the `perform` with the args.
    #
    # @return [Any] The result of the perform.
    #
    def execute
      perform(*job_args)
    end
  end
end
