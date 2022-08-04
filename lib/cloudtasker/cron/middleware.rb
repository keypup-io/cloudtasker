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
          config.server_middleware do |c|
            # Make sure cron server middleware always run before unique job middleware
            # to prevent some rare cases where the next cron job cannot be scheduled because of lock.
            if defined?(::Cloudtasker::UniqueJob::Middleware::Server)
              c.insert_before(Cloudtasker::UniqueJob::Middleware::Server, Middleware::Server)
            else
              c.add(Middleware::Server)
            end
          end
        end
      end
    end
  end
end
