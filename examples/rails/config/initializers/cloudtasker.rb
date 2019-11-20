# frozen_string_literal: true

require 'cloudtasker/unique_job'
require 'cloudtasker/cron'
require 'cloudtasker/batch'

Cloudtasker.configure do |config|
  config.secret = 'some-rails-secret'
  # config.logger = Rails.logger
  config.gcp_location_id = 'us-east1'
  config.gcp_project_id = 'some-project'
  config.gcp_queue_id = 'some-queue'
  config.processor_host = 'http://localhost:3000'
end

unless Rails.env.test?
  Cloudtasker::Cron::Schedule.load_from_hash!(
    'my_worker' => {
      'worker' => 'CronWorker',
      'cron' => '* * * * *'
    }
  )
end
