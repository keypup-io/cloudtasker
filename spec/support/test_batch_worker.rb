# frozen_string_literal: true

class TestBatchWorker
  include Cloudtasker::Worker

  class << self
    attr_accessor :callback_registry, :callback_error_counts
  end

  def perform(level = 0)
    # Initialize callback counters on top parent's run
    if level == 0
      self.class.callback_registry = {}
      self.class.callback_error_counts = {}
    end

    # Fail jobs on their first few runs
    raise(StandardError, 'batch worker error') if job_retries < level

    # Enqueue child jobs
    2.times { batch.add(self.class, level + 1) } if level < 2

    # Expand parent batch. Limit batch expansion to level 2 only (last child level)
    # to avoid infinite loops. Expand batch before the job starts failing on on_batch_complete.
    2.times { parent_batch.add(self.class, level + 1) } if level == 2 && job_retries < 3
  end

  # Hook invoked when a batch completes
  def on_batch_complete
    level = job_args[0].to_i

    # Fail callbacks on their first few runs
    self.class.callback_error_counts[job_id] ||= 0
    self.class.callback_error_counts[job_id] += 1
    raise(StandardError, 'batch callback error') if self.class.callback_error_counts[job_id] <= 2

    # Register batch as complete
    self.class.callback_registry[level] ||= Set.new
    self.class.callback_registry[level].add(job_id)
  end

  # Return the number of jobs completed per level
  def self.callback_counts
    callback_registry.transform_values(&:size)
  end
end
