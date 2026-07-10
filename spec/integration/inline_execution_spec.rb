# frozen_string_literal: true

require 'spec_helper'
require 'cloudtasker/batch/middleware'

# Contract for Cloudtasker::Testing.inline!: within an inline! block a job runs
# as the real server would. That holds because inline execution happens in
# Backend::MemoryTask.create — the single point through which all enqueue paths
# funnel — and from there goes through WorkerHandler.with_worker_handling.
#
# These specs pin three consequences of that, only some of which are covered
# elsewhere (e.g. the batch integration spec drains a fake! queue manually
# rather than running inline!):
#
#   1. Execution coverage — every enqueue path runs (perform_async,
#      perform_at/perform_in, the instance #schedule method, batch children).
#   2. Error hooks — a raising job fires the on_error hook.
#   3. Context fidelity — the worker runs with a task_id.
RSpec.describe 'Testing.inline! server-path fidelity' do
  before { TestWorker.has_run = false }

  # Control: .perform_async is the one path most inline handling focuses on.
  describe '.perform_async' do
    it 'runs the job inline' do
      Cloudtasker::Testing.inline! { TestWorker.perform_async(2, 3) }
      expect(TestWorker.has_run).to be(true)
    end
  end

  # Scheduled jobs must still run immediately in inline mode — the delay/eta is
  # ignored, exactly as with an immediately-enqueued job.
  describe '.perform_in' do
    it 'runs the scheduled job inline despite the delay' do
      Cloudtasker::Testing.inline! { TestWorker.perform_in(60, 2, 3) }
      expect(TestWorker.has_run).to be(true)
    end
  end

  describe '.perform_at' do
    it 'runs the scheduled job inline despite the schedule time' do
      Cloudtasker::Testing.inline! { TestWorker.perform_at(Time.now + 3600, 2, 3) }
      expect(TestWorker.has_run).to be(true)
    end
  end

  # Jobs enqueued through the instance #schedule method — the path used by batch
  # children — must also run inline.
  describe '#schedule' do
    it 'runs the job inline' do
      Cloudtasker::Testing.inline! { TestWorker.new(job_args: [2, 3]).schedule }
      expect(TestWorker.has_run).to be(true)
    end
  end

  # Batch children are enqueued via #schedule (not .perform_async), so an inline!
  # batch must run the parent AND every child synchronously. We assert on child
  # execution only (not completion callbacks) to stay orthogonal to batch
  # completion semantics.
  describe 'batch children' do
    before { Cloudtasker::Batch::Middleware.configure }
    before { TestInlineBatchWorker.runs = nil }

    it 'runs the parent and all children inline' do
      Cloudtasker::Testing.inline! { TestInlineBatchWorker.perform_async }

      # Parent (level 0) plus CHILD_COUNT children (level 1).
      expect(TestInlineBatchWorker.runs.sort).to eq([0, 1, 1, 1])
    end
  end

  # An inline job that raises must still be routed through
  # WorkerHandler.with_worker_handling, so the on_error / on_dead hooks fire
  # exactly as they do on the real server. A refactor that executes the worker
  # directly (bypassing with_worker_handling) silently drops these hooks even
  # though the job itself still runs.
  describe 'error handling hooks' do
    before { TestErrorWorker.has_run = false }

    it 'invokes the on_error hook when an inline job raises' do
      reported = []
      allow(Cloudtasker.config).to receive(:on_error).and_return(->(error, worker) { reported << [error, worker] })

      expect do
        Cloudtasker::Testing.inline! { TestErrorWorker.perform_async(true) }
      end.to raise_error(StandardError, 'test error')

      expect(TestErrorWorker.has_run).to be(true)
      expect(reported.size).to eq(1)
      expect(reported.first.first).to be_a(StandardError)
    end
  end

  # Inline execution should reproduce the server execution context — including a
  # task_id, which applications read for logging and error instrumentation. A
  # refactor that runs the worker straight from its args (without the backend's
  # task assignment) leaves task_id nil and silently degrades that context.
  describe 'execution context' do
    before { TestContextWorker.last_task_id = nil }

    it 'runs the inline job with a task_id, like the server path' do
      Cloudtasker::Testing.inline! { TestContextWorker.perform_async }

      expect(TestContextWorker.last_task_id).not_to be_nil
    end
  end
end
