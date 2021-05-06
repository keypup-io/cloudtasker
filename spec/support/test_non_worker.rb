# frozen_string_literal: true

class TestNonWorker
  attr_accessor :job_id, :job_meta

  def initialize(*_args)
    @job_meta = Cloudtasker::MetaStore.new
  end
end
