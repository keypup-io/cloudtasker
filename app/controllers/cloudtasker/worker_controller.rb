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
      WorkerHandler.execute_from_payload!(request.params.slice(:worker, :args))
      head :no_content
    rescue InvalidWorkerError
      head :not_found
    rescue StandardError
      head :unprocessable_entity
    end

    private

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
