# frozen_string_literal: true

require 'cloudtasker/backend/google_cloud_task'
require 'cloudtasker/config'

ENV['GOOGLE_AUTH_SUPPRESS_CREDENTIALS_WARNINGS'] ||= 'true'

namespace :cloudtasker do
  desc 'Setup a Cloud Task queue. (default options: ' \
    "name=#{Cloudtasker::Config::DEFAULT_JOB_QUEUE}, " \
    "concurrency=#{Cloudtasker::Config::DEFAULT_QUEUE_CONCURRENCY}, " \
    "retries=#{Cloudtasker::Config::DEFAULT_QUEUE_RETRIES})"
  task setup_queue: :environment do
    puts Cloudtasker::Backend::GoogleCloudTask.setup_queue(
      name: ENV['name'],
      concurrency: ENV['concurrency'],
      retries: ENV['retries']
    )
  end
end
