# frozen_string_literal: true

class TestUniqueJobWorker
  include Cloudtasker::Worker

  class << self
    attr_accessor :past_job_args
  end

  cloudtasker_options lock: 'until_executed'

  def perform(arg1, arg2)
    (self.class.past_job_args ||= []) << [arg1, arg2]
    arg1 + arg2
  end
end
