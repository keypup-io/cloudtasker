# frozen_string_literal: true

require 'cloudtasker/config'
require 'cloudtasker/cloud_task'

ENV['GOOGLE_AUTH_SUPPRESS_CREDENTIALS_WARNINGS'] ||= 'true'

namespace :cloudtasker do
  desc 'Setup a Cloud Task queue. (default options: ' \
       "name=#{Cloudtasker::Config::DEFAULT_JOB_QUEUE}, " \
       "concurrency=#{Cloudtasker::Config::DEFAULT_QUEUE_CONCURRENCY}, " \
       "retries=#{Cloudtasker::Config::DEFAULT_QUEUE_RETRIES})"
  task setup_queue: :environment do
    puts Cloudtasker::CloudTask.setup_production_queue(
      name: ENV.fetch('name', nil),
      concurrency: ENV.fetch('concurrency', nil),
      retries: ENV.fetch('retries', nil)
    )
  end
end
