# frozen_string_literal: true

require 'cloudtasker/worker'

module Cloudtasker
  # A worker class used to schedule jobs without actually
  # instantiating the worker class. This is useful for middlewares
  # needing to enqueue jobs in a Rails initializer. Rails 6 complains
  # about instantiating workers in an iniitializer because of autoloading
  # in zeitwerk mode.
  #
  # Downside of this wrapper: any cloudtasker_options specified on on the
  # worker_class will be ignored.
  #
  # See: https://github.com/rails/rails/issues/36363
  #
  class WorkerWrapper
    include Worker

    attr_accessor :worker_name

    #
    # Build a new instance of the class.
    #
    # @param [String] worker_class The name of the worker class.
    # @param [Hash] **opts The worker arguments.
    #
    def initialize(worker_name:, **opts)
      @worker_name = worker_name
      super(**opts)
    end

    #
    # Override parent. Return the underlying worker class name.
    #
    # @return [String] The worker class.
    #
    def job_class_name
      worker_name
    end

    #
    # Return a new instance of the worker with the same args and metadata
    # but with a different id.
    #
    # @return [Cloudtasker::WorkerWrapper] <description>
    #
    def new_instance
      self.class.new(worker_name: worker_name, job_queue: job_queue, job_args: job_args, job_meta: job_meta)
    end
  end
end
