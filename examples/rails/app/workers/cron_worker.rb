# frozen_string_literal: true

class CronWorker
  include Cloudtasker::Worker

  def perform(arg1)
    Rails.logger.info("#{self.class} starting with arg1=#{arg1}...")
    sleep(3)
    Rails.logger.info("#{self.class} done!")
  end
end
