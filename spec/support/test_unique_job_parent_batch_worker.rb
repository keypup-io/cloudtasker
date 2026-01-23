# frozen_string_literal: true

class TestUniqueJobParentBatchWorker
  include Cloudtasker::Worker

  def perform(arg1, arg2)
    batch.add(TestUniqueJobWorker, arg1, arg2)
    batch.add(TestUniqueJobWorker, arg1, arg2)
  end
end
