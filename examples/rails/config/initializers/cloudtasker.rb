# frozen_string_literal: true

require 'cloudtasker/unique_job'
require 'cloudtasker/cron'
require 'cloudtasker/batch'

Cloudtasker.configure do |config|
  #
  # GCP Configuration
  #
  config.gcp_location_id = 'us-east1'
  config.gcp_project_id = 'some-project'
  config.gcp_queue_prefix = 'my-app'

  #
  # Domain
  #
  # config.processor_host = 'https://xxxx.ngrok.io'
  #
  config.processor_host = 'http://localhost:3000'

  #
  # Uncomment to process tasks via Cloud Task.
  # Requires a ngrok tunnel.
  #
  # config.mode = :production

  #
  # Global error Hooks
  #
  config.on_error = lambda { |error, worker|
    Rails.logger.error("Uh oh... worker #{worker&.job_id} had the following error: #{error}")
  }
  config.on_dead = ->(error, worker) { Rails.logger.error("Damn... worker #{worker&.job_id} died with: #{error}") }
end

#
# Setup cron job
#
# Cloudtasker::Cron::Schedule.load_from_hash!(
#   'my_worker' => {
#     'worker' => 'CronWorker',
#     'cron' => '* * * * *',
#     'queue' => 'critical',
#     'args' => ['foo']
#   }
# )
