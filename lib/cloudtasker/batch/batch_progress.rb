# frozen_string_literal: true

require 'fugit'

module Cloudtasker
  module Batch
    # Capture the progress of a batch
    class BatchProgress
      attr_reader :batches

      #
      # Build a new instance of the class.
      #
      # @param [Array<Cloudtasker::Batch::Job>] batches The batches to consider
      #
      def initialize(batches = [])
        @batches = batches
      end

      # Count the number of items in a given status

      #
      # Count the number of items in a given status
      #
      # @param [String] status The status to count
      #
      # @return [Integer] The number of jobs in the status
      #
      def count(status = 'all')
        batches.sum { |e| e.batch_state_count(status) }
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
        total - done
      end

      #
      # Return the number of jobs completed or dead.
      #
      # @return [Integer] The number of jobs done.
      #
      def done
        completed + dead
      end

      #
      # Return the batch progress percentage.
      #
      # A `min_total` can be specified to linearize the calculation, while jobs get added at
      # the start of the batch.
      #
      # Similarly a `smoothing` parameter can be specified to add a constant to the total
      # and linearize the calculation, which becomes: `done / (total + smoothing)`
      #
      # @param [Integer] min_total The minimum for the total number of jobs
      # @param [Integer] smoothing An additive smoothing for the total number of jobs
      #
      # @return [Float] The progress percentage.
      #
      def percent(min_total: 0, smoothing: 0)
        # Get the total value to use
        actual_total = [min_total, total + smoothing].max

        # Abort if we cannot divide
        return 0 if actual_total.zero?

        # Calculate progress
        (done.to_f / actual_total) * 100
      end

      #
      # Add a batch progress to another one.
      #
      # @param [Cloudtasker::Batch::BatchProgress] progress The progress to add.
      #
      # @return [Cloudtasker::Batch::BatchProgress] The sum of the two batch progresses.
      #
      def +(other)
        self.class.new(batches + other.batches)
      end
    end
  end
end
