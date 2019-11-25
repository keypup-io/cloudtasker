# frozen_string_literal: true

class DummyWorker
  include Cloudtasker::Worker

  def perform
    Rails.logger.info('Dummy worker starting...')
    sleep(3)
    Rails.logger.info('Dummy worker done!')
  end
end
