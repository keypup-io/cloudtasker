# frozen_string_literal: true

class TestMiddleware
  attr_accessor :arg, :called

  def initialize(arg = nil)
    @arg = arg
  end

  def call(worker, **kwargs)
    @called = true
    worker.middleware_called = true if worker.respond_to?(:middleware_called)
    worker.middleware_opts = kwargs if worker.respond_to?(:middleware_opts)
    yield
  end
end
