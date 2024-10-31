# frozen_string_literal: true

RSpec.describe Cloudtasker::CloudScheduler::Job::WorkerPayload do
  let(:worker) { TestWorker.new(job_args: ['foo'], job_queue: 'my_queue') }
  let(:payload) { described_class.new(worker) }

  describe '#to_h' do
    subject(:hash) { payload.to_h }

    it { is_expected.to be_a(Hash) }

    it {
      expect(hash).to include(
        'worker' => 'TestWorker', 'job_id' => worker.job_id,
        'job_args' => ['foo'], 'job_queue' => 'my_queue'
      )
    }
  end
end
