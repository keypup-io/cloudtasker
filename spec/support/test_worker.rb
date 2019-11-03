# frozen_string_literal: true

class TestWorker
  include Cloudtasker::Worker

  def perform(arg1, arg2)
    arg1 + arg2
  end
end
