# frozen_string_literal: true

require 'cloudtasker/version'
require 'cloudtasker/config'

require 'cloudtasker/authentication_error'
require 'cloudtasker/invalid_worker_error'

require 'cloudtasker/middleware/chain'
require 'cloudtasker/authenticator'
require 'cloudtasker/task'
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

  def self.config
    @config ||= Config.new
  end
end

require 'cloudtasker/engine' if defined?(::Rails::Engine)
