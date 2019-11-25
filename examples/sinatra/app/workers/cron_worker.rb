# frozen_string_literal: true

class CronWorker
  include Cloudtasker::Worker

  def perform
    logger.info("#{self.class} starting...")
    sleep(3)
    logger.info("#{self.class} done!")
  end
end
