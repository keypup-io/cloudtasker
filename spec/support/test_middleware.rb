# frozen_string_literal: true

class TestMiddleware
  attr_accessor :arg, :called

  def initialize(arg = nil)
    @arg = arg
  end

  def call(worker)
    @called = true
    worker.middleware_called = true if worker.respond_to?(:middleware_called)
    yield
  end
end
