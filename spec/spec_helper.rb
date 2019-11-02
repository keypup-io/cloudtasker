# frozen_string_literal: true

require 'bundler/setup'
require 'timecop'
require 'cloudtasker'

# Require supporting files
Dir['./spec/support/**/*.rb'].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# Configure for tests
Cloudtasker.configure do |config|
  # GCP
  config.gcp_project_id = 'my-project-id'
  config.gcp_location_id = 'us-east2'
  config.gcp_queue_id = 'my-queue'

  # Processor
  config.secret = 'my$s3cr3t'
  config.processor_host = 'http://localhost'
  config.processor_path = '/mynamespace/run'
end
