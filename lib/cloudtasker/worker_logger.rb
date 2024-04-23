# frozen_string_literal: true

module Cloudtasker
  # Add contextual information to logs generated
  # by workers
  class WorkerLogger
    attr_accessor :worker

    class << self
      attr_accessor :log_context_processor

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      #
      # Truncate an array or hash payload.
      #
      # This can be used to log arguments on jobs while still keeping logs to a
      # reasonable size.
      #
      # @param [Hash,Array] payload The payload to truncate
      # @param [Integer] string_limit The maximum size for strings. Set to -1 to disable.
      # @param [Integer] array_limit The maximum length for arrays. Set to -1 to disable.
      # @param [Hash] max_depth The maximum recursive depth. Set to -1 to disable.
      #
      # @return [Hash,Array] The truncated payload
      #
      def truncate(payload, **kwargs)
        depth = kwargs[:depth].to_i
        max_depth = kwargs[:max_depth] || 3
        string_limit = kwargs[:string_limit] || 64
        array_limit = kwargs[:array_limit] || 10

        case payload
        when Array
          if max_depth > -1 && depth > max_depth
            ["...#{payload.size} items..."]
          elsif array_limit > -1
            payload.take(array_limit).map { |e| truncate(e, **kwargs, depth: depth + 1) } +
              (payload.size > array_limit ? ["...#{payload.size - array_limit} items..."] : [])
          else
            payload.map { |e| truncate(e, **kwargs, depth: depth + 1) }
          end
        when Hash
          if max_depth > -1 && depth > max_depth
            '{hash}'
          else
            payload.transform_values { |e| truncate(e, **kwargs, depth: depth + 1) }
          end
        when String
          if string_limit > -1 && payload.size > string_limit
            payload.truncate(string_limit)
          else
            payload
          end
        else
          payload
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    end

    # Only log the job meta information by default (exclude arguments)
    DEFAULT_CONTEXT_PROCESSOR = ->(worker) { worker.to_h.slice(:worker, :job_id, :job_meta, :job_queue, :task_id) }

    #
    # Build a new instance of the class.
    #
    # @param [Cloudtasker::Worker] worker The worker.
    #
    def initialize(worker)
      @worker = worker
    end

    #
    # Return the Proc responsible for formatting the log payload.
    #
    # @return [Proc] The context processor.
    #
    def context_processor
      @context_processor ||= worker.class.cloudtasker_options_hash[:log_context_processor] ||
                             self.class.log_context_processor ||
                             DEFAULT_CONTEXT_PROCESSOR
    end

    #
    # The block to pass to log messages.
    #
    # @return [Proc] The log block.
    #
    def log_block
      @log_block ||= proc { context_processor.call(worker) }
    end

    #
    # Return the Cloudtasker logger.
    #
    # @return [Logger, any] The cloudtasker logger.
    #
    def logger
      Cloudtasker.logger
    end

    #
    # Format the log message as string.
    #
    # @param [Object] msg The log message or object.
    #
    # @return [String] The formatted message
    #
    def formatted_message_as_string(msg)
      # Format message
      msg_content = if msg.is_a?(Exception)
                      [msg.inspect, msg.backtrace].flatten(1).join("\n")
                    elsif msg.is_a?(String)
                      msg
                    else
                      msg.inspect
                    end

      "[Cloudtasker][#{worker.class}][#{worker.job_id}] #{msg_content}"
    end

    #
    # Format main log message.
    #
    # @param [String] msg The message to log.
    #
    # @return [String] The formatted log message
    #
    def formatted_message(msg)
      if msg.is_a?(String)
        formatted_message_as_string(msg)
      else
        # Delegate object formatting to logger
        msg
      end
    end

    #
    # Log an info message.
    #
    # @param [String] msg The message to log.
    # @param [Proc] &block Optional context block.
    #
    def info(msg, &block)
      log_message(:info, msg, &block)
    end

    #
    # Log an error message.
    #
    # @param [String] msg The message to log.
    # @param [Proc] &block Optional context block.
    #
    def error(msg, &block)
      log_message(:error, msg, &block)
    end

    #
    # Log an fatal message.
    #
    # @param [String] msg The message to log.
    # @param [Proc] &block Optional context block.
    #
    def fatal(msg, &block)
      log_message(:fatal, msg, &block)
    end

    #
    # Log an debut message.
    #
    # @param [String] msg The message to log.
    # @param [Proc] &block Optional context block.
    #
    def debug(msg, &block)
      log_message(:debug, msg, &block)
    end

    #
    # Delegate all methods to the underlying logger.
    #
    # @param [String, Symbol] name The method to delegate.
    # @param [Array<any>] *args The list of method arguments.
    # @param [Proc] &block Block passed to the method.
    #
    # @return [Any] The method return value
    #
    def method_missing(name, *args, &block)
      if logger.respond_to?(name)
        logger.send(name, *args, &block)
      else
        super
      end
    end

    #
    # Check if the class respond to a certain method.
    #
    # @param [String, Symbol] name The name of the method.
    # @param [Boolean] include_private Whether to check private methods or not. Default to false.
    #
    # @return [Boolean] Return true if the class respond to this method.
    #
    def respond_to_missing?(name, include_private = false)
      logger.respond_to?(name) || super
    end

    private

    #
    # Log a message for the provided log level.
    #
    # @param [String, Symbol] level The log level
    # @param [String] msg The message to log.
    # @param [Proc] &block Optional context block.
    #
    def log_message(level, msg, &block)
      # Merge log-specific context into worker-specific context
      payload_block = ->(*_args) { log_block.call.merge(block&.call || {}) }

      # ActiveSupport::Logger does not support passing a payload through a block on top
      # of a message.
      if defined?(ActiveSupport::Logger) && logger.is_a?(ActiveSupport::Logger)
        # The logger is fairly basic in terms of formatting. All inputs get converted
        # as regular strings.
        logger.send(level) { "#{formatted_message_as_string(msg)} -- #{payload_block.call}" }
      else
        logger.send(level, formatted_message(msg), &payload_block)
      end
    end
  end
end
