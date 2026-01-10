# frozen_string_literal: true

module Cloudtasker
  # Error raised when a worker class cannot be instantiated.
  class InvalidWorkerError < StandardError
    def initialize(worker_name = nil)
      super(worker_name ? "Invalid worker: #{worker_name}" : 'Invalid worker')
    end
  end
end
