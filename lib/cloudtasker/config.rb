# frozen_string_literal: true

require 'logger'

module Cloudtasker
  # Holds cloudtasker configuration. See Cloudtasker#configure
  class Config
    attr_accessor :redis
    attr_writer :secret, :gcp_location_id, :gcp_project_id,
                :gcp_queue_prefix, :processor_path, :logger, :mode, :max_retries

    # Max Cloud Task size in bytes
    MAX_TASK_SIZE = 100 * 1024 # 100 KB

    # Retry header in Cloud Task responses
    RETRY_HEADER = 'X-CloudTasks-TaskExecutionCount'

    # Content-Transfer-Encoding header in Cloud Task responses
    ENCODING_HEADER = 'Content-Transfer-Encoding'

    # Content Type
    CONTENT_TYPE_HEADER = 'Content-Type'

    # Authorization header
    AUTHORIZATION_HEADER = 'Authorization'

    # Default values
    DEFAULT_LOCATION_ID = 'us-east1'
    DEFAULT_PROCESSOR_PATH = '/cloudtasker/run'

    # Default queue values
    DEFAULT_JOB_QUEUE = 'default'
    DEFAULT_QUEUE_CONCURRENCY = 10
    DEFAULT_QUEUE_RETRIES = -1 # unlimited

    # The number of times jobs will be attempted before declaring them dead
    DEFAULT_MAX_RETRY_ATTEMPTS = 25

    PROCESSOR_HOST_MISSING = <<~DOC
      Missing host for processing.
      Please specify a processor hostname in form of `https://some-public-dns.example.com`'
    DOC
    QUEUE_PREFIX_MISSING_ERROR = <<~DOC
      Missing GCP queue prefix.
      Please specify a queue prefix in the form of `my-app`.
      You can create a default queue using the Google SDK via `gcloud tasks queues create my-app-default`
    DOC
    PROJECT_ID_MISSING_ERROR = <<~DOC
      Missing GCP project ID.
      Please specify a project ID in the cloudtasker configurator.
    DOC
    SECRET_MISSING_ERROR = <<~DOC
      Missing cloudtasker secret.
      Please specify a secret in the cloudtasker initializer or add Rails secret_key_base in your credentials
    DOC

    #
    # The number of times jobs will be retried. This number of
    # retries does not include failures due to the application being unreachable.
    #
    #
    # @return [Integer] The number of retries
    #
    def max_retries
      @max_retries ||= DEFAULT_MAX_RETRY_ATTEMPTS
    end

    #
    # The operating mode.
    #   - :production => process tasks via GCP Cloud Task.
    #   - :development => process tasks locally via Redis.
    #
    # @return [<Type>] <description>
    #
    def mode
      @mode ||= environment == 'development' ? :development : :production
    end

    #
    # Return the current environment.
    #
    # @return [String] The environment name.
    #
    def environment
      ENV['CLOUDTASKER_ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
    end

    #
    # Return the Cloudtasker logger.
    #
    # @return [Logger, any] The cloudtasker logger.
    #
    def logger
      @logger ||= defined?(Rails) ? Rails.logger : ::Logger.new(STDOUT)
    end

    #
    # Return the full URL of the processor. Worker payloads will be sent
    # to this URL.
    #
    # @return [String] The processor URL.
    #
    def processor_url
      File.join(processor_host, processor_path)
    end

    #
    # Set the processor host. In the context of Rails the host will
    # also be added to the list of authorized Rails hosts.
    #
    # @param [String] val The processor host to set.
    #
    def processor_host=(val)
      @processor_host = val

      # Check if Rails supports host filtering
      return unless val &&
                    defined?(Rails) &&
                    Rails.application.config.respond_to?(:hosts) &&
                    Rails.application.config.hosts&.any?

      # Add processor host to the list of authorized hosts
      Rails.application.config.hosts << val.gsub(%r{https?://}, '')
    end

    #
    # The hostname of the application processing the workers. The hostname must
    # be reachable from Cloud Task.
    #
    # @return [String] The processor host.
    #
    def processor_host
      @processor_host || raise(StandardError, PROCESSOR_HOST_MISSING)
    end

    #
    # The path on the host when worker payloads will be sent.
    # Default to `/cloudtasker/run`
    #
    #
    # @return [String] The processor path
    #
    def processor_path
      @processor_path || DEFAULT_PROCESSOR_PATH
    end

    #
    # Return the prefix used for queues.
    #
    # @return [String] The prefix of the processing queues.
    #
    def gcp_queue_prefix
      @gcp_queue_prefix || raise(StandardError, QUEUE_PREFIX_MISSING_ERROR)
    end

    #
    # Return the GCP project ID.
    #
    # @return [String] The ID of the project for which tasks will be processed.
    #
    def gcp_project_id
      @gcp_project_id || raise(StandardError, PROJECT_ID_MISSING_ERROR)
    end

    #
    # Return the GCP location ID. Default to 'us-east1'
    #
    # @return [String] The location ID where tasks will be processed.
    #
    def gcp_location_id
      @gcp_location_id || DEFAULT_LOCATION_ID
    end

    #
    # Return the secret to use to sign the verification tokens
    # attached to tasks.
    #
    # @return [String] The cloudtasker secret
    #
    def secret
      @secret || (
        defined?(Rails) && Rails.application.credentials&.dig(:secret_key_base)
      ) || raise(StandardError, SECRET_MISSING_ERROR)
    end

    #
    # Return the chain of client middlewares.
    #
    # @return [Cloudtasker::Middleware::Chain] The chain of middlewares.
    #
    def client_middleware
      @client_middleware ||= Middleware::Chain.new
      yield @client_middleware if block_given?
      @client_middleware
    end

    #
    # Return the chain of server middlewares.
    #
    # @return [Cloudtasker::Middleware::Chain] The chain of middlewares.
    #
    def server_middleware
      @server_middleware ||= Middleware::Chain.new
      yield @server_middleware if block_given?
      @server_middleware
    end
  end
end
