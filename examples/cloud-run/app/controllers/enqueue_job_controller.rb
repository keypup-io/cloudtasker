# frozen_string_literal: true

# A simple controller that enqueues jobs for test
# purpose on Cloud Run
class EnqueueJobController < ApplicationController
  # GET /enqueue/dummy
  def dummy
    DummyWorker.perform_async

    render plain: 'DummyWorker enqueued'
  end
end
