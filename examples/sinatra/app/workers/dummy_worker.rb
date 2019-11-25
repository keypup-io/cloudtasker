# frozen_string_literal: true

class DummyWorker
  include Cloudtasker::Worker

  def perform
    logger.info('Dummy worker starting...')
    sleep(3)
    logger.info('Dummy worker done!')
  end
end
