# frozen_string_literal: true

class TestStorableWorker
  include Cloudtasker::Worker
  include Cloudtasker::Storable::Worker

  attr_accessor :middleware_called, :middleware_opts, :has_run

  class << self
    attr_accessor :has_run

    def has_run?
      has_run
    end
  end

  cloudtasker_options foo: 'bar'

  def perform(arg1, arg2)
    self.class.has_run = true
    arg1 + arg2
  end
end
