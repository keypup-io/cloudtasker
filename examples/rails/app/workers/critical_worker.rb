# frozen_string_literal: true

class CriticalWorker
  include Cloudtasker::Worker

  cloudtasker_options queue: :critical

  def perform
    Rails.logger.info('Critical worker starting...')
    sleep(3)
    Rails.logger.info('Critical worker done!')
  end
end
