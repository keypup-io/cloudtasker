# frozen_string_literal: true

module Cloudtasker
  # Rails extensions
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/setup_queue.rake'
    end
  end
end
