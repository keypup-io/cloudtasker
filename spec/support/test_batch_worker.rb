# frozen_string_literal: true

class TestBatchWorker
  include Cloudtasker::Worker

  class << self
    attr_accessor :callback_counts, :callback_error_counts
  end

  def perform(level = 0)
    # Flag parent as incomplete
    if level == 0
      self.class.callback_counts = {}
      self.class.callback_error_counts = {}
    end

    # Fail jobs on their first few runs
    raise(StandardError, 'batch worker error') if job_retries < level

    # Enqueue child jobs
    2.times { batch.add(self.class, level + 1) } if level < 2
  end

  def on_batch_complete
    level = job_args[0].to_i

    # Fail callbacks on their first few runs
    self.class.callback_error_counts[job_id] ||= 0
    self.class.callback_error_counts[job_id] += 1
    raise(StandardError, 'batch callback error') if self.class.callback_error_counts[job_id] <= 2

    # Add callback result
    self.class.callback_counts[level] ||= 0
    self.class.callback_counts[level] += 1
  end
end
