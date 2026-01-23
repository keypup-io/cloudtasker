# frozen_string_literal: true

require 'spec_helper'
require 'cloudtasker/batch/middleware'

RSpec.describe 'Unique Worker' do
  before do
    # Activate middlewares
    Cloudtasker::Batch::Middleware.configure
    Cloudtasker::UniqueJob::Middleware.configure

    # Reset tracking of past jobs
    TestUniqueJobWorker.past_job_args = nil
  end

  describe 'concurrent enqueuing of standalone jobs with same args' do
    before do
      Cloudtasker::Testing.fake! do
        TestUniqueJobWorker.perform_async(1, 2)
        TestUniqueJobWorker.perform_async(1, 2)
      end
    end

    it { expect(TestUniqueJobWorker.jobs.size).to eq(1) }
  end

  describe 'concurrent enqueuing of standalone jobs with different args' do
    before do
      Cloudtasker::Testing.fake! do
        TestUniqueJobWorker.perform_async(1, 2)
        TestUniqueJobWorker.perform_async(2, 2)
      end
    end

    it { expect(TestUniqueJobWorker.jobs.size).to eq(2) }
  end

  describe 'concurrent enqueuing vs run of standalone jobs with different args' do
    before do
      Cloudtasker::Testing.fake! do
        TestUniqueJobWorker.perform_async(1, 2)
        TestUniqueJobWorker.perform_now(2, 2)
      end
    end

    it 'schedules the first job and does not execute the second job' do
      expect(TestUniqueJobWorker.jobs.size).to eq(1)
      expect(TestUniqueJobWorker.past_job_args).to eq([[2, 2]])
    end
  end

  describe 'successive enqueuing+run of standalone jobs with same args' do
    before do
      Cloudtasker::Testing.fake! do
        TestUniqueJobWorker.perform_async(1, 2)
        Cloudtasker::Worker.drain_all
        TestUniqueJobWorker.perform_async(1, 2)
        Cloudtasker::Worker.drain_all
      end
    end

    it 'processes both jobs' do
      expect(TestUniqueJobWorker.jobs.size).to eq(0)
      expect(TestUniqueJobWorker.past_job_args).to eq([[1, 2], [1, 2]])
    end
  end

  describe 'concurrent enqueuing of a standalone job and batch sub-job (lock_per_batch: true)' do
    before do
      orig_options = TestUniqueJobWorker.cloudtasker_options_hash
      TestUniqueJobWorker.cloudtasker_options(orig_options.merge(lock_per_batch: true))

      Cloudtasker::Testing.fake! do
        # This will immediately enqueue two TestUniqueJobWorker attached to a batch.
        # Only one will be effectively enqueued due to uniqueness.
        TestUniqueJobParentBatchWorker.perform_now(1, 2)

        # This is our standalone job. It will be enqueued since it's not part of the
        # same batch (same uniqueness scope) as the ones enqueued via the batch.
        TestUniqueJobWorker.perform_async(1, 2)
      end

      TestUniqueJobWorker.cloudtasker_options(orig_options)
    end

    it { expect(TestUniqueJobWorker.jobs.size).to eq(2) }
  end

  describe 'concurrent enqueuing of a standalone job and batch sub-job (lock_per_batch: false)' do
    before do
      Cloudtasker::Testing.fake! do
        # This will immediately enqueue two TestUniqueJobWorker attached to a batch.
        # Only one will be effectively enqueued due to uniqueness.
        TestUniqueJobParentBatchWorker.perform_now(1, 2)

        # This is our standalone job. It will not enqueued since lock_per_batch is false
        # therefore setting a global scope for uniqueness
        TestUniqueJobWorker.perform_async(1, 2)
      end
    end

    it { expect(TestUniqueJobWorker.jobs.size).to eq(1) }
  end
end
