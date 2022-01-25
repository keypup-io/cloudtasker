# frozen_string_literal: true

# Require cloudtasker and its extensions
require 'cloudtasker'
require 'cloudtasker/unique_job'
require 'cloudtasker/cron'
require 'cloudtasker/batch'

Cloudtasker.configure do |config|
  #
  # Secret used to authenticate job requests
  #
  config.secret = 'some-secret'

  #
  # GCP Configuration
  #
  config.gcp_project_id = 'some-project'
  config.gcp_location_id = 'us-east1'
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
