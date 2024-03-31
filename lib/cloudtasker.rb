# frozen_string_literal: true

require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/string/filters'
require 'active_support/security_utils'

require 'cloudtasker/version'
require 'cloudtasker/config'

require 'cloudtasker/authentication_error'
require 'cloudtasker/dead_worker_error'
require 'cloudtasker/retry_worker_error'
require 'cloudtasker/invalid_worker_error'
require 'cloudtasker/missing_worker_arguments_error'
require 'cloudtasker/max_task_size_exceeded_error'

require 'cloudtasker/middleware/chain'
require 'cloudtasker/authenticator'
require 'cloudtasker/cloud_task'
require 'cloudtasker/worker_logger'
require 'cloudtasker/worker_handler'
require 'cloudtasker/meta_store'
require 'cloudtasker/worker'

# Define and manage Cloud Task based workers
module Cloudtasker
  attr_writer :config

  #
  # Cloudtasker configurator.
  #
  def self.configure
    yield(config)
  end

  #
  # Return the Cloudtasker configuration.
  #
  # @return [Cloudtasker::Config] The Cloudtasker configuration.
  #
  def self.config
    @config ||= Config.new
  end

  #
  # Return the Cloudtasker logger.
  #
  # @return [Logger] The Cloudtasker logger.
  #
  def self.logger
    config.logger
  end
end

require 'cloudtasker/engine' if defined?(Rails::Engine)
