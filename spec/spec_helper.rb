# frozen_string_literal: true

require 'bundler/setup'
require 'timecop'
require 'webmock/rspec'
require 'semantic_logger'

# Configure Rails dummary app
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('dummy/config/environment.rb', __dir__)
require 'rspec/rails'
require 'rspec/json_expectations'

# Require main library (after Rails has done so)
require 'cloudtasker'
require 'cloudtasker/testing'
require 'cloudtasker/unique_job'
require 'cloudtasker/cron'
require 'cloudtasker/batch'

# Require supporting files
Dir['./spec/support/**/*.rb'].each { |f| require f }
Dir['./spec/shared/**/*.rb'].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Ensure cache is clean before each test
  config.before do
    Cloudtasker.config.client_middleware.clear
    Cloudtasker.config.server_middleware.clear

    # Flush redis keys
    Cloudtasker::RedisClient.new.clear
  end

  # Note: Retriable is configured in a conditional before
  # block to avoid requiring the gem in the spec helper. This
  # ensures that classes have defined the proper requires.
  config.before(:all) do
    if defined?(Retriable)
      # Do not wait between retries
      Retriable.configure do |c|
        c.multiplier    = 1.0
        c.rand_factor   = 0.0
        c.base_interval = 0
      end
    end
  end
end

# Configure for tests
Cloudtasker.configure do |config|
  # GCP
  config.gcp_project_id = 'my-project-id'
  config.gcp_location_id = 'us-east2'
  config.gcp_queue_prefix = 'my-queue'

  # Processor
  config.secret = 'my$s3cr3t'
  config.processor_host = 'http://localhost'
  config.processor_path = '/mynamespace/run'

  # Redis
  config.redis = { url: "redis://#{ENV['REDIS_HOST'] || 'localhost'}:6379/15" }

  # Logger
  config.logger = Logger.new(nil)

  # Hooks
  config.on_error = ->(w, e) {}
  config.on_dead = ->(w, e) {}
end
