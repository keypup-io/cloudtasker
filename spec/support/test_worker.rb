# frozen_string_literal: true

class TestWorker
  include Cloudtasker::Worker

  attr_accessor :middleware_called

  def perform(arg1, arg2)
    arg1 + arg2
  end
end
