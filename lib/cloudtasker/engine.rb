# frozen_string_literal: true

module Cloudtasker
  # Cloudtasker Rails engine
  class Engine < ::Rails::Engine
    isolate_namespace Cloudtasker

    # Setup cloudtasker processing route
    initializer 'cloudtasker', before: :load_config_initializers do
      Rails.application.routes.append do
        mount Cloudtasker::Engine, at: '/cloudtasker'
      end
    end

    # Setup active job adapter
    initializer 'cloudtasker.active_job', after: :load_config_initializers do
      require 'active_job/queue_adapters/cloudtasker_adapter' if defined?(::ActiveJob::Railtie)
    end

    config.generators do |g|
      g.test_framework :rspec, fixture: false
      g.assets false
      g.helper false
    end
  end
end
