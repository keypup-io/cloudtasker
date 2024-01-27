# frozen_string_literal: true

RSpec.describe Cloudtasker::CloudScheduler::Job::ActiveJobPayload do
  let(:worker) { TestActiveJob.new }
  let(:payload) { described_class.new(worker) }

  before do
    allow(worker).to receive(:job_id).and_return('123')
    allow(worker).to receive(:queue_name).and_return('my_queue')
    allow(worker).to receive(:serialize).and_return('serialized_job')
  end

  describe '#to_h' do
    subject(:hash) { payload.to_h }

    it { is_expected.to be_a(Hash) }

    it {
      expect(hash).to include(
        'worker' => 'ActiveJob::QueueAdapters::CloudtaskerAdapter::JobWrapper',
        'job_id' => '123', 'job_args' => ['serialized_job'],
        'job_queue' => 'my_queue', 'job_meta' => {}
      )
    }
  end
end
