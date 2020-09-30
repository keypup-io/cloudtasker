# frozen_string_literal: true

require 'rack/utils'

module Cloudtasker
  # Handle execution of workers
  class WorkerController
    delegate :call, to: :class

    def self.call(env)
      processor = ActionRouter.match_processor(env)

      processor.perform
    end

    # Base module used by any pretended request processor
    module RequestResponder
      attr_reader :request

      def initialize(env)
        @request = Rack::Request.new(env)
      end

      private

      def head(status)
        status_code = Rack::Utils::SYMBOL_TO_STATUS_CODE[status]
        [status_code, {}, []]
      end
    end

    # Processes Run Requests
    class RunRequestProcessor
      include RequestResponder

      def perform
        authenticate_request
        process_received_payload
        head :no_content
      rescue AuthenticationError
        head :unauthorized
      rescue DeadWorkerError
        # 205: job will NOT be retried
        head :reset_content
      rescue InvalidWorkerError
        # 404: Job will be retried
        head :not_found
      rescue StandardError => error
        # 404: Job will be retried
        Cloudtasker.logger.error(error)
        Cloudtasker.logger.error(error.backtrace.join("\n"))
        head :unprocessable_entity
      end

      # Parse the request body and return the actual job payload.
      #
      # @return [Hash] The job payload
      #
      def payload
        @payload ||= JSON.parse(request_content).merge(
          job_retries: job_retries, task_id: task_id
        )
      end

      def content_encoded?
        request_encoding_header.casecmp?('base64')
      end

      private

      # Authenticate incoming requests using a bearer token
      #
      # See Cloudtasker::Authenticator#verification_token
      #
      def authenticate_request
        Authenticator.verify!(request_authorization_header)
      end

      def process_received_payload
        WorkerHandler.execute_from_payload!(payload)
      end

      def request_content
        raw_content = request.body.read
        return raw_content unless content_encoded?

        Base64.decode64(raw_content)
      end

      def request_authorization_header
        request_header('Authorization').to_s.split(' ').last
      end

      # NOTE: This is just a simple implementation of a proper env-to-header
      # mapper, and is intended to work only for the headers used in this class.
      def request_header(header_name)
        env_name = 'HTTP_' + header_name.upcase.tr('-', '_')
        request.env[env_name]
      end

      def request_encoding_header
        request_header(Cloudtasker::Config::ENCODING_HEADER).to_s
      end

      # Extract the number of times this task failed at runtime.
      #
      # @return [Integer] The number of failures.
      #
      def job_retries
        request_header(Cloudtasker::Config::RETRY_HEADER).to_i
      end

      # Return the Google Cloud Task ID from headers.
      #
      # @return [String] The task ID.
      #
      def task_id
        request_header(Cloudtasker::Config::TASK_ID_HEADER)
      end
    end

    # A simple class that routes request to it's intended processor
    class ActionRouter
      ROUTE_MATCHERS = {
        ['POST', '/run'] => RunRequestProcessor
      }.freeze

      attr_reader :env

      def initialize(env)
        @env = env
      end

      def matched_processor
        processor_class = ROUTE_MATCHERS[request_matcher] || NullProcessor
        processor_class.new(env)
      end

      def self.match_processor(env)
        new(env).matched_processor
      end

      private

      # A null-object request processor used when the route doesn't match a
      # real processor.
      class NullProcessor
        include RequestResponder

        def perform
          head :not_found
        end
      end

      def request_matcher
        [env['REQUEST_METHOD'], env['PATH_INFO'].delete_prefix('/cloudtasker')]
      end
    end
  end
end
