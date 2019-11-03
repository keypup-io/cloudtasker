# frozen_string_literal: true

module Cloudtasker
  # Cloud Task based workers
  module Worker
    # Add class method to including class
    def self.included(base)
      base.extend(ClassMethods)
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
        Task.new(worker: self, args: args).schedule(interval: interval)
      end
    end
  end
end
