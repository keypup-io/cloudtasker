# frozen_string_literal: true

module Cloudtasker
  # Cloudtasker Rails engine
  class Engine < ::Rails::Engine
    isolate_namespace Cloudtasker

    config.before_initialize do
      # Mount cloudtasker processing endpoint
      Rails.application.routes.append do
        mount Cloudtasker::Engine, at: '/cloudtasker'
      end

      # Add ActiveJob adapter
      require 'active_job/queue_adapters/cloudtasker_adapter' if defined?(::ActiveJob::Railtie)
    end

    config.generators do |g|
      g.test_framework :rspec, fixture: false
      g.assets false
      g.helper false
    end
  end
end
