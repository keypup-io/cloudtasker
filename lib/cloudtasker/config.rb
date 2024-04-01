# frozen_string_literal: true

require 'logger'

module Cloudtasker
  # Holds cloudtasker configuration. See Cloudtasker#configure
  class Config
    attr_accessor :redis, :store_payloads_in_redis, :gcp_queue_prefix
    attr_writer :secret, :gcp_location_id, :gcp_project_id,
                :processor_path, :logger, :mode, :max_retries,
                :dispatch_deadline, :on_error, :on_dead, :oidc, :local_server_ssl_verify

    # Max Cloud Task size in bytes
    MAX_TASK_SIZE = 100 * 1024 # 100 KB

    # Retry header in Cloud Task responses
    #
    # Definitions:
    #   X-CloudTasks-TaskRetryCount: total number of retries (including 504 "instance unreachable")
    #   X-CloudTasks-TaskExecutionCount: number of non-503 retries (= actual number of job failures)
    #
    RETRY_HEADER = 'X-Cloudtasks-Taskexecutioncount'

    # Cloud Task ID header
    TASK_ID_HEADER = 'X-CloudTasks-TaskName'

    # Content-Transfer-Encoding header in Cloud Task responses
    ENCODING_HEADER = 'Content-Transfer-Encoding'

    # Content Type
    CONTENT_TYPE_HEADER = 'Content-Type'

    # OIDC Authorization header
    OIDC_AUTHORIZATION_HEADER = 'Authorization'

    # Custom authentication header that does not conflict with
    # OIDC authorization header
    CT_AUTHORIZATION_HEADER = 'X-Cloudtasker-Authorization'
    CT_SIGNATURE_HEADER = 'X-Cloudtasker-Signature'

    # Default values
    DEFAULT_LOCATION_ID = 'us-east1'
    DEFAULT_PROCESSOR_PATH = '/cloudtasker/run'
    DEFAULT_LOCAL_SERVER_SSL_VERIFY_MODE = true

    # Default queue values
    DEFAULT_JOB_QUEUE = 'default'
    DEFAULT_QUEUE_CONCURRENCY = 10
    DEFAULT_QUEUE_RETRIES = -1 # unlimited

    # Job timeout configuration for Cloud Tasks
    DEFAULT_DISPATCH_DEADLINE = 10 * 60 # 10 minutes
    MIN_DISPATCH_DEADLINE = 15 # seconds
    MAX_DISPATCH_DEADLINE = 30 * 60 # 30 minutes

    # Default on_error Proc
    DEFAULT_ON_ERROR = ->(error, worker) {}

    # Cache key prefix used to store workers in cache and retrieve
    # them later.
    WORKER_STORE_PREFIX = 'worker_store'

    # The number of times jobs will be attempted before declaring them dead.
    #
    # With the default retry configuration (maxDoublings = 16 and minBackoff = 0.100s)
    # it means that jobs will be declared dead after 20h of consecutive failing.
    #
    # Note that this configuration parameter is internal to Cloudtasker and does not
    # affect the Cloud Task queue configuration. The number of retries configured
    # on the Cloud Task queue should be higher than the number below to also cover
    # failures due to the instance being unreachable.
    DEFAULT_MAX_RETRY_ATTEMPTS = 25

    PROCESSOR_HOST_MISSING = <<~DOC
      Missing host for processing.
      Please specify a processor hostname in form of `https://some-public-dns.example.com`'
    DOC
    PROJECT_ID_MISSING_ERROR = <<~DOC
      Missing GCP project ID.
      Please specify a project ID in the cloudtasker configurator.
    DOC
    SECRET_MISSING_ERROR = <<~DOC
      Missing cloudtasker secret.
      Please specify a secret in the cloudtasker initializer or add Rails secret_key_base in your credentials
    DOC
    OIDC_EMAIL_MISSING_ERROR = <<~DOC
      Missing OpenID Connect (OIDC) service account email.
      You specified an OIDC configuration hash but the :service_account_email property is missing.
    DOC

    #
    # Return the threshold above which job arguments must be stored
    # in Redis instead of being sent to the backend as part of the job
    # payload.
    #
    # Return nil if redis payload storage is disabled.
    #
    # @return [Integer, nil] The threshold above which payloads will be stored in Redis.
    #
    def redis_payload_storage_threshold
      return nil unless store_payloads_in_redis

      store_payloads_in_redis.respond_to?(:to_i) ? store_payloads_in_redis.to_i : 0
    end

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
      @logger ||= defined?(Rails) ? Rails.logger : ::Logger.new($stdout)
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
    # Return the Dispatch deadline duration. Cloud Tasks will timeout the job after
    # this duration is elapsed.
    #
    # @return [Integer] The value in seconds.
    #
    def dispatch_deadline
      @dispatch_deadline || DEFAULT_DISPATCH_DEADLINE
    end

    #
    # Return the secret to use to sign the verification tokens
    # attached to tasks.
    #
    # @return [String] The cloudtasker secret
    #
    def secret
      @secret ||= (
        defined?(Rails) && Rails.application.credentials&.dig(:secret_key_base)
      ) || raise(StandardError, SECRET_MISSING_ERROR)
    end

    #
    # Return a Proc invoked whenever a worker runtime error is raised.
    # See Cloudtasker::WorkerHandler.with_worker_handling
    #
    # @return [Proc] A Proc handler
    #
    def on_error
      @on_error || DEFAULT_ON_ERROR
    end

    #
    # Return a Proc invoked whenever a worker DeadWorkerError is raised.
    # See Cloudtasker::WorkerHandler.with_worker_handling
    #
    # @return [Proc] A Proc handler
    #
    def on_dead
      @on_dead || DEFAULT_ON_ERROR
    end

    #
    # Return the Open ID Connect configuration to use for tasks.
    #
    # @return [Hash] The OIDC configuration
    #
    def oidc
      return unless @oidc
      raise(StandardError, OIDC_EMAIL_MISSING_ERROR) unless @oidc[:service_account_email]

      {
        service_account_email: @oidc[:service_account_email],
        audience: @oidc[:audience] || processor_host
      }
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

    #
    # Return the ssl verify mode for the Cloudtasker local server.
    #
    # @return [Boolean] The ssl verify mode for the Cloudtasker local server.
    #
    def local_server_ssl_verify
      @local_server_ssl_verify.nil? ? DEFAULT_LOCAL_SERVER_SSL_VERIFY_MODE : @local_server_ssl_verify
    end
  end
end
