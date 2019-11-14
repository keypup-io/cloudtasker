# frozen_string_literal: true

require 'cloudtasker/unique_job/middleware'

RSpec.describe Cloudtasker::UniqueJob::Lock::UntilExecuted do
  let(:worker) { TestWorker.new(job_args: [1, 2], job_id: SecureRandom.uuid) }
  let(:job) { Cloudtasker::UniqueJob::Job.new(worker) }
  let(:lock) { described_class.new(job) }

  it_behaves_like Cloudtasker::UniqueJob::Lock::BaseLock

  describe '#schedule' do
    it { expect { |b| lock.schedule(&b) }.to yield_control }
  end

  describe '#execute' do
    it { expect { |b| lock.execute(&b) }.to yield_control }
  end
end
