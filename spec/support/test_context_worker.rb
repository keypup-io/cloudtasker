# frozen_string_literal: true

# Records the execution context (task_id) seen inside #perform, so specs can
# assert that an inline-executed job carries the same context as the real
# server path (where the backend assigns a task_id).
class TestContextWorker
  include Cloudtasker::Worker

  class << self
    attr_accessor :last_task_id
  end

  def perform
    self.class.last_task_id = task_id
  end
end
