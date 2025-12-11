# frozen_string_literal: true

class TestErrorWorker
  include Cloudtasker::Worker

  attr_accessor :has_run

  class << self
    attr_accessor :has_run

    def has_run?
      has_run
    end
  end

  # rubocop:disable Style/OptionalBooleanParameter
  def perform(should_error = true)
    self.class.has_run = true
    raise StandardError, 'test error' if should_error

    'success'
  end
  # rubocop:enable Style/OptionalBooleanParameter
end
