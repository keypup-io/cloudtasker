# frozen_string_literal: true

ENV['GOOGLE_AUTH_SUPPRESS_CREDENTIALS_WARNINGS'] ||= 'true'

namespace :cloudtasker do
  DEFAULT_FILE = 'config/cloudtasker_cron.yml'

  desc "Setup CloudScheduler. (default options: file=#{DEFAULT_FILE})"
  task setup_cloud_scheduler: :environment do
    Cloudtasker::CloudScheduler::Manager.synchronize!(DEFAULT_FILE)
  end
end
