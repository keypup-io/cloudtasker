# frozen_string_literal: true

# Minimal batch worker used to exercise Cloudtasker::Testing.inline! execution.
#
# The parent (level 0) enqueues CHILD_COUNT children; each run appends its level
# to a class-level registry so specs can assert that batch children execute
# synchronously in inline mode. Children (level 1) add no further jobs.
class TestInlineBatchWorker
  include Cloudtasker::Worker

  CHILD_COUNT = 3

  class << self
    attr_accessor :runs
  end

  def perform(level = 0)
    self.class.runs ||= []
    self.class.runs << level.to_i

    CHILD_COUNT.times { batch.add(self.class, 1) } if level.to_i.zero?
  end
end
