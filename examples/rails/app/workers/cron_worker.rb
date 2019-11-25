# frozen_string_literal: true

class CronWorker
  include Cloudtasker::Worker

  def perform
    Rails.logger.info("#{self.class} starting...")
    sleep(3)
    Rails.logger.info("#{self.class} done!")
  end
end
