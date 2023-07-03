# frozen_string_literal: true

Cloudtasker.configure do |config|
  #
  # GCP Configuration
  #
  config.gcp_project_id = 'your-project-id'
  config.gcp_location_id = 'us-central1'
  config.gcp_queue_prefix = 'cloudtasker-demo'

  #
  # Domain
  #
  # config.processor_host = 'https://xxxx.ngrok.io'
  #
  config.processor_host = 'https://your-cloud-run-service.a.run.app'

  # OpenID Connect configuration
  # You need to create a IAM service account first. See the README.
  # config.oidc = { service_account_email: 'cloudtasker-demo@your-project-id.iam.gserviceaccount.com' }
end
