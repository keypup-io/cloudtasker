# frozen_string_literal: true

require 'cloudtasker'
require 'cloudtasker/local_server'

module Cloudtasker
  # Cloudtasker executable logic
  module CLI
    module_function

    #
    # Return the current environment.
    #
    # @return [String] The environment name.
    #
    def environment
      Cloudtasker.config.environment
    end

    #
    # Return true if we are running in Rails.
    #
    # @return [Boolean] True if rails is loaded.
    #
    def rails_app?
      defined?(::Rails)
    end

    #
    # Return true if we are running in JRuby.
    #
    # @return [Boolean] True if JRuby is loaded.
    #
    def jruby?
      defined?(::JRUBY_VERSION)
    end

    #
    # Return the Cloudtasker logger
    #
    # @return [Logger] The Cloudtasker logger.
    #
    def logger
      Cloudtasker.logger
    end

    #
    # Return the local Cloudtasker server.
    #
    # @return [Cloudtasker::LocalServer] The local Cloudtasker server.
    #
    def local_server
      @local_server ||= LocalServer.new
    end

    #
    # Load Rails if defined
    #
    def boot_system
      # Sync logs
      $stdout.sync = true

      # Check for Rails
      return false unless File.exist?('./config/environment.rb')

      require 'rails'
      require 'cloudtasker/engine'
      require File.expand_path('./config/environment.rb')
    end

    #
    # Run the cloudtasker development server.
    #
    def run(opts = {})
      boot_system

      # Print banner
      environment == 'development' ? print_banner : print_non_dev_warning

      # Print rails info
      if rails_app?
        logger.info "[Cloudtasker/Server] Booted Rails #{::Rails.version} application in #{environment} environment"
      end

      # Get internal read/write pip
      self_read, self_write = IO.pipe

      # Setup signals to trap
      setup_signals(self_write)

      logger.info "[Cloudtasker/Server] Running in #{RUBY_DESCRIPTION}"

      # Wait for signals
      run_server(self_read, opts)
    end

    #
    # Run server and wait for signals.
    #
    # @param [IO] read_pipe Where to read signals.
    # @param [Hash] opts Server options.
    #
    def run_server(read_pipe, opts = {})
      local_server.start(opts)

      while (readable_io = read_pipe.wait_readable)
        signal = readable_io.first[0].gets.strip
        handle_signal(signal)
      end
    rescue Interrupt
      logger.info 'Shutting down'
      local_server.stop
      logger.info 'Stopped'
    end

    #
    # Define which signals to trap
    #
    # @param [IO] write_pipe Where to write signals.
    #
    def setup_signals(write_pipe)
      # Display signals on log output
      sigs = %w[INT TERM TTIN TSTP]
      # USR1 and USR2 don't work on the JVM
      sigs << 'USR2' unless jruby?
      sigs.each do |sig|
        trap(sig) { write_pipe.puts(sig) }
      rescue ArgumentError
        puts "Signal #{sig} not supported"
      end
    end

    #
    # Handle process signals
    #
    # @param [String] sig The signal.
    #
    def handle_signal(sig)
      raise(Interrupt) if %w[INT TERM].include?(sig)
    end

    #
    # Return the server banner
    #
    # @return [String] The server banner
    #
    def banner
      <<~'TEXT'
           ___ _                 _ _            _
          / __\ | ___  _   _  __| | |_ __ _ ___| | _____ _ __
         / /  | |/ _ \| | | |/ _` | __/ _` / __| |/ / _ \ '__|
        / /___| | (_) | |_| | (_| | || (_| \__ \   <  __/ |
        \____/|_|\___/ \__,_|\__,_|\__\__,_|___/_|\_\___|_|

      TEXT
    end

    #
    # Display a warning message when run in non-dev env.
    #
    # @return [<Type>] <description>
    #
    def print_non_dev_warning
      puts "\e[31m"
      puts non_dev_warning_message
      puts "\e[0m"
    end

    #
    # Return the message to display when users attempt to run
    # the local development server in non-dev environments.
    #
    # @return [String] The warning message.
    #
    def non_dev_warning_message
      <<~'TEXT'
        ============================================ /!\ ====================================================
        Your are running the Cloudtasker local development server in a NON-DEVELOPMENT environment.
        This is not recommended as the the development server is not designed for production-like load.
        If you need a job processing server to run yourself please use Sidekiq instead (https://sidekiq.org)
        ============================================ /!\ ====================================================
      TEXT
    end

    #
    # Print the server banner
    #
    def print_banner
      puts "\e[96m"
      puts banner
      puts "\e[0m"
    end
  end
end
