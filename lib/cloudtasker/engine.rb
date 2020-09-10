# frozen_string_literal: true

module Cloudtasker
  # Cloudtasker Rails engine
  class Engine < ::Rails::Engine
    isolate_namespace Cloudtasker

    initializer 'cloudtasker', before: :load_config_initializers do
      Rails.application.routes.append do
        mount Cloudtasker::Engine, at: '/cloudtasker'
      end
    end

    config.before_configuration do
      require 'active_job/queue_adapters/cloudtasker_adapter'
    end

    config.after_initialize do
      require 'active_job/queue_adapters/cloudtasker_adapter/job_wrapper'
    end

    config.generators do |g|
      g.test_framework :rspec, fixture: false
      g.assets false
      g.helper false
    end
  end
end
