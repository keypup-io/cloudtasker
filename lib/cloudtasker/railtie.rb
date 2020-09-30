# frozen_string_literal: true

module Cloudtasker
  # Cloudtasker Railtie
  class Railtie < ::Rails::Railtie
    initializer 'cloudtasker', before: :load_config_initializers do
      Rails.application.routes.append do
        mount Cloudtasker::WorkerController, at: '/cloudtasker'
      end
    end
  end
end
