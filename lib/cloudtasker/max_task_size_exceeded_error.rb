# frozen_string_literal: true

module Cloudtasker
  # Handle Cloud Task size quota
  # See: https://cloud.google.com/appengine/quotas#Task_Queue
  #
  class MaxTaskSizeExceededError < StandardError
    MSG = 'The size of Cloud Tasks must not exceed 100KB'

    def initialize(msg = MSG)
      super
    end
  end
end
