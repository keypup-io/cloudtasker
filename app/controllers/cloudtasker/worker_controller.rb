# frozen_string_literal: true

module Cloudtasker
  # Handle execution of workers
  class WorkerController < ApplicationController
    # Authenticate all requests.
    before_action :authenticate!

    # Return 401 when API Token is invalid
    rescue_from AuthenticationError do
      head :unauthorized
    end

    # POST /cloudtasker/run
    #
    # Run a worker from a Cloud Task payload
    #
    def run
      # Process payload
      WorkerHandler.execute_from_payload!(payload)
      head :no_content
    rescue DeadWorkerError, MissingWorkerArgumentsError => e
      # 205: job will NOT be retried
      log_error(e)
      head :reset_content
    rescue InvalidWorkerError => e
      # 404: Job will be retried
      log_error(e)
      head :not_found
    rescue StandardError => e
      # 404: Job will be retried
      log_error(e)
      head :unprocessable_entity
    end

    private

    #
    # Log an error via cloudtasker logger.
    #
    # @param [Exception] e The error to log
    #
    def log_error(error)
      Cloudtasker.logger.error(error)
      Cloudtasker.logger.error(error.backtrace.join("\n"))
    end

    #
    # Parse the request body and return the actual job
    # payload.
    #
    # @return [Hash] The job payload
    #
    def payload
      @payload ||= begin
        # Get raw body
        content = request.body.read

        # Decode content if the body is Base64 encoded
        if request.headers[Cloudtasker::Config::ENCODING_HEADER].to_s.downcase == 'base64'
          content = Base64.decode64(content)
        end

        # Return content parsed as JSON and add job retries count
        JSON.parse(content).merge(job_retries: job_retries, task_id: task_id)
      end
    end

    #
    # Extract the number of times this task failed at runtime.
    #
    # @return [Integer] The number of failures.
    #
    def job_retries
      request.headers[Cloudtasker::Config::RETRY_HEADER].to_i
    end

    #
    # Return the Google Cloud Task ID from headers.
    #
    # @return [String] The task ID.
    #
    def task_id
      request.headers[Cloudtasker::Config::TASK_ID_HEADER]
    end

    #
    # Authenticate incoming requests using a bearer token
    #
    # See Cloudtasker::Authenticator#verification_token
    #
    def authenticate!
      Authenticator.verify!(request.headers['Authorization'].to_s.split(' ').last)
    end
  end
end
