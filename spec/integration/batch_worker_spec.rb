# frozen_string_literal: true

require 'spec_helper'
require 'cloudtasker/batch/middleware'

RSpec.describe 'Batch Worker' do
  # Activate middleware
  before { Cloudtasker::Batch::Middleware.configure }

  describe 'regular batch' do
    let(:worker_class) { TestBatchWorker }
    let(:expected_callback_counts) do
      {
        # 1 level 0
        0 => 1,
        # 1 (level 0) * 2 (level 1)
        1 => 2,
        # 1 (level 0) * 2 (level 1) * 2 (level 2)
        2 => 4,
        # 1 (level 0) * 2 (level 1) * 2 (level 2) * 2 (level 3 / batch expansion) *
        3 => 8
      }
    end

    before do
      # Perform jobs
      Cloudtasker::Testing.fake! do
        worker_class.perform_async

        # Process jobs iteratively until the batch is complete
        # Limit the number of iterations to 50 to prevent unexpected infinite loops
        50.times do
          Cloudtasker::Worker.drain_all
          break if worker_class.jobs.blank?
        end
      end
    end

    it 'completes the batch' do
      expect(TestBatchWorker.jobs).to be_blank
      expect(TestBatchWorker.callback_counts).to eq(expected_callback_counts)
    end
  end

  describe 'dead batch' do
    let(:worker_class) { DeadBatchWorker }

    let(:expected_callback_counts) do
      {
        # (1 level 0 succeed)
        0 => 1,
        # (2 level 1 success)
        1 => 2
        # No level 2 - they all failed
      }
    end

    before do
      # Perform jobs
      Cloudtasker::Testing.fake! do
        worker_class.perform_async

        # Process jobs iteratively until the batch is complete
        # Limit the number of iterations to 50 to prevent unexpected infinite loops
        # The batch
        50.times do
          Cloudtasker::Worker.drain_all
          break if worker_class.jobs.blank?
        end
      end
    end

    it 'completes the batch' do
      expect(worker_class.jobs).to be_blank
      expect(worker_class.callback_counts).to eq(expected_callback_counts)
    end
  end
end
