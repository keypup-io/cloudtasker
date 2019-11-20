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
      # @return [Array<Cloudtasker::Worker] The list of workers
      #
      def jobs
        Backend::MemoryTask.jobs(to_s)
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
