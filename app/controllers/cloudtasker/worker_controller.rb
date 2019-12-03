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
      # Build payload
      payload = JSON.parse(request.body.read).merge(job_retries: job_retries)

      # Process payload
      WorkerHandler.execute_from_payload!(payload)
      head :no_content
    rescue DeadWorkerError
      # 205: job will NOT be retried
      head :reset_content
    rescue InvalidWorkerError
      # 404: Job will be retried
      head :not_found
    rescue StandardError => e
      # 404: Job will be retried
      Cloudtasker.logger.error(e)
      Cloudtasker.logger.error(e.backtrace.join("\n"))
      head :unprocessable_entity
    end

    private

    #
    # Extract the number of times this task failed at runtime.
    #
    # @return [Integer] The number of failures
    #
    def job_retries
      request.headers[Cloudtasker::Config::RETRY_HEADER].to_i
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
