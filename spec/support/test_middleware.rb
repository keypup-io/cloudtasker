# frozen_string_literal: true

class TestMiddleware
  attr_accessor :arg, :called

  def initialize(arg = nil)
    @arg = arg
  end

  def call(_worker)
    puts 'called'
    @called = true
    yield
  end
end
