# frozen_string_literal: true

require 'fugit'

module Cloudtasker
  module Batch
    # Capture the progress of a batch
    class BatchProgress
      attr_reader :batch_state

      #
      # Build a new instance of the class.
      #
      # @param [Hash] batch_state The batch state
      #
      def initialize(batch_state = {})
        @batch_state = batch_state
      end

      #
      # Return the total number jobs.
      #
      # @return [Integer] The number number of jobs.
      #
      def total
        count
      end

      #
      # Return the number of completed jobs.
      #
      # @return [Integer] The number of completed jobs.
      #
      def completed
        @completed ||= count('completed')
      end

      #
      # Return the number of scheduled jobs.
      #
      # @return [Integer] The number of scheduled jobs.
      #
      def scheduled
        @scheduled ||= count('scheduled')
      end

      #
      # Return the number of processing jobs.
      #
      # @return [Integer] The number of processing jobs.
      #
      def processing
        @processing ||= count('processing')
      end

      #
      # Return the number of jobs with errors.
      #
      # @return [Integer] The number of errored jobs.
      #
      def errored
        @errored ||= count('errored')
      end

      #
      # Return the number of dead jobs.
      #
      # @return [Integer] The number of dead jobs.
      #
      def dead
        @dead ||= count('dead')
      end

      #
      # Return the number of jobs not completed yet.
      #
      # @return [Integer] The number of jobs pending.
      #
      def pending
        total - completed - dead
      end

      #
      # Return the batch progress percentage.
      #
      # @return [Float] The progress percentage.
      #
      def percent
        return 0 if total.zero?

        pending.to_f / total
      end

      #
      # Add a batch progress to another one.
      #
      # @param [Cloudtasker::Batch::BatchProgress] progress The progress to add.
      #
      # @return [Cloudtasker::Batch::BatchProgress] The sum of the two batch progresses.
      #
      def +(other)
        self.class.new(batch_state.to_h.merge(other.batch_state.to_h))
      end

      private

      # Count the number of items in a given status
      def count(status = nil)
        return batch_state.to_h.keys.size unless status

        batch_state.to_h.values.count { |e| e == status }
      end
    end
  end
end
