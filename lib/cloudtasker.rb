# frozen_string_literal: true

require 'cloudtasker/version'
require 'cloudtasker/config'
require 'cloudtasker/task'

# Define and manage Cloud Task based workers
module Cloudtasker
  attr_reader :config

  #
  # Cloudtasker configurator.
  #
  def self.configure
    self.config = Config.new
    yield(config)
  end
end
