# frozen_string_literal: true

require 'cloudtasker/redis_client'

require_relative 'extension/worker'
require_relative 'config'
require_relative 'batch_progress'
require_relative 'job'

require_relative 'middleware/server'

module Cloudtasker
  module Batch
    # Registration module
    module Middleware
      def self.configure
        Cloudtasker.configure do |config|
          config.server_middleware { |c| c.add(Middleware::Server) }
        end
        Cloudtasker::Worker.include(Extension::Worker)
      end
    end
  end
end
