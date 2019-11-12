# frozen_string_literal: true

class TestMiddleware3
  def call(_worker)
    yield
  end
end
