# frozen_string_literal: true

class TestPropagateQueueSubWorker
  include Cloudtasker::Worker

  cloudtasker_options queue: 'queue-that-will-be-overriden-by-parent'

  def perform
    true
  end
end
