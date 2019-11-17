# frozen_string_literal: true

class MyWorker
  include Cloudtasker::Worker

  def perform
    true
  end
end
