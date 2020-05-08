# frozen_string_literal: true

class TestWorker2
  include Cloudtasker::Worker

  attr_accessor :middleware_called, :middleware_opts

  cloudtasker_options foo: 'bar'

  def perform(arg1, arg2)
    arg1 + arg2
  end
end
