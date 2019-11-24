# frozen_string_literal: true

require 'cloudtasker/backend/google_cloud_task'

namespace :cloudtasker do
  desc 'Setup the Cloud Task queue'
  task setup_queue: :environment do
    Cloudtasker::Backend::GoogleCloudTask.setup_queue
  end
end
