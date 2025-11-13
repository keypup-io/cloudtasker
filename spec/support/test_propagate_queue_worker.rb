# frozen_string_literal: true

class TestPropagateQueueWorker
  include Cloudtasker::Worker

  cloudtasker_options queue: 'queue-that-overrides-children', propagate_queue: true

  def perform
    TestPropagateQueueSubWorker.perform_async
  end
end
