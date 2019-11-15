# frozen_string_literal: true

require 'cloudtasker/unique_job/middleware'

RSpec.describe Cloudtasker::UniqueJob::ConflictStrategy::Raise do
  let(:worker) { TestWorker.new(job_args: [1, 2]) }
  let(:job) { Cloudtasker::UniqueJob::Job.new(worker) }
  let(:strategy) { described_class.new(job) }

  it_behaves_like Cloudtasker::UniqueJob::ConflictStrategy::BaseStrategy

  describe '#on_schedule' do
    it { expect { strategy.on_schedule }.to raise_error(Cloudtasker::UniqueJob::LockError) }
  end

  describe '#on_execute' do
    it { expect { strategy.on_execute }.to raise_error(Cloudtasker::UniqueJob::LockError) }
  end
end
