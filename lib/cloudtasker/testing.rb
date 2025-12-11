# frozen_string_literal: true

require 'cloudtasker/backend/memory_task'

module Cloudtasker
  # Enable/Disable test mode for Cloudtasker
  module Testing
    module_function

    #
    # Set the test mode, either permanently or
    # temporarily (via block).
    #
    # @param [Symbol] mode The test mode.
    #
    # @return [Symbol] The test mode.
    #
    def switch_test_mode(mode)
      if block_given?
        current_mode = @test_mode
        begin
          @test_mode = mode
          yield
        ensure
          @test_mode = current_mode
        end
      else
        @test_mode = mode
      end
    end

    #
    # Set the error mode, either permanently or
    # temporarily (via block).
    #
    # @param [Symbol] mode The error mode.
    #
    # @return [Symbol] The error mode.
    #
    def switch_error_mode(mode)
      if block_given?
        current_mode = @error_mode
        begin
          @error_mode = mode
          yield
        ensure
          @error_mode = current_mode
        end
      else
        @error_mode = mode
      end
    end

    #
    # Set cloudtasker to real mode temporarily
    #
    # @param [Proc] &block The block to run in real mode
    #
    def enable!(&block)
      switch_test_mode(:enabled, &block)
    end

    #
    # Set cloudtasker to fake mode temporarily
    #
    # @param [Proc] &block The block to run in fake mode
    #
    def fake!(&block)
      switch_test_mode(:fake, &block)
    end

    #
    # Set cloudtasker to inline mode temporarily
    #
    # @param [Proc] &block The block to run in inline mode
    #
    def inline!(&block)
      switch_test_mode(:inline, &block)
    end

    #
    # Return true if Cloudtasker is enabled.
    #
    def enabled?
      !@test_mode || @test_mode == :enabled
    end

    #
    # Return true if Cloudtasker is in fake mode.
    #
    # @return [Boolean] True if jobs must be processed through drain calls.
    #
    def fake?
      @test_mode == :fake
    end

    #
    # Return true if Cloudtasker is in inline mode.
    #
    # @return [Boolean] True if jobs are run inline.
    #
    def inline?
      @test_mode == :inline
    end

    #
    # Temporarily raise errors in the same manner
    # inline! does it.
    #
    # This is used when you want to manually drain the jobs
    # but still want to surface errors at runtime, instead of
    # using the retry mechanic.
    #
    def raise_errors!(&block)
      switch_error_mode(:raise, &block)
    end

    #
    # Temporarily silence errors. Job will follow the retry logic.
    #
    def silence_errors!(&block)
      switch_error_mode(:silence, &block)
    end

    #
    # Return true if jobs should raise errors immediately
    # without relying on retries.
    #
    # @return [Boolean] True if jobs are run inline.
    #
    def raise_errors?
      @test_mode == :inline || @error_mode == :raise
    end

    #
    # Return true if tasks should be managed in memory.
    #
    # @return [Boolean] True if jobs are managed in memory.
    #
    def in_memory?
      !enabled?
    end
  end

  # Add extra methods for testing purpose
  module Worker
    #
    # Clear all jobs.
    #
    def self.clear_all
      Backend::MemoryTask.clear
    end

    #
    # Run all the jobs.
    #
    # @return [Array<any>] The return values of the workers perform method.
    #
    def self.drain_all
      Backend::MemoryTask.drain
    end

    # Module class methods
    module ClassMethods
      #
      # Return all jobs related to this worker class.
      #
      # @return [Array<Cloudtasker::Backend::MemoryTask>] The list of tasks
      #
      def jobs
        Backend::MemoryTask.all(to_s)
      end

      #
      # Run all jobs related to this worker class.
      #
      # @return [Array<any>] The return values of the workers perform method.
      #
      def drain
        Backend::MemoryTask.drain(to_s)
      end
    end
  end
end
