# frozen_string_literal: true

require 'cloudtasker/redis_client'

require_relative 'schedule'
require_relative 'job'
require_relative 'middleware/server'

module Cloudtasker
  module Cron
    # Registration module
    module Middleware
      def self.configure
        Cloudtasker.configure do |config|
          config.server_middleware { |c| c.add(Middleware::Server) }
        end
      end
    end
  end
end
