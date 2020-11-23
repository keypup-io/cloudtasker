# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'action_controller/railtie'
require 'active_job/railtie'

Bundler.require(*Rails.groups)
require 'cloudtasker'

module Dummy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults Rails.version.to_f

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
    config.eager_load = false

    # Use cloudtasker as the ActiveJob backend:
    config.active_job.queue_adapter = :cloudtasker
  end
end
