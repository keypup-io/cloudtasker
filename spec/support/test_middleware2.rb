# frozen_string_literal: true

class TestMiddleware2
  def call(_worker)
    yield
  end
end
