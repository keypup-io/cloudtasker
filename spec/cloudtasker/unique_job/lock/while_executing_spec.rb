# frozen_string_literal: true

require 'cloudtasker/unique_job/middleware'

RSpec.describe Cloudtasker::UniqueJob::Lock::WhileExecuting do
  let(:worker) { TestWorker.new(job_args: [1, 2]) }
  let(:job) { Cloudtasker::UniqueJob::Job.new(worker) }
  let(:lock) { described_class.new(job) }

  it_behaves_like Cloudtasker::UniqueJob::Lock::BaseLock

  describe '#schedule' do
    it { expect { |b| lock.schedule(&b) }.to yield_control }
  end

  describe '#execute' do
    context 'with lock available' do
      before { allow(job).to receive(:lock!) }
      before { allow(job).to receive(:unlock!) }
      after { expect(job).to have_received(:unlock!) }
      it { expect { |b| lock.execute(&b) }.to yield_control }
    end

    context 'with lock acquired by another job' do
      before { allow(job).to receive(:lock!).and_raise(Cloudtasker::UniqueJob::LockError) }
      before { allow(lock.conflict_instance).to receive(:on_execute) }
      after { expect(lock.conflict_instance).to have_received(:on_execute) { |&b| expect(b).to be_a(Proc) } }
      it { expect { |b| lock.execute(&b) }.not_to yield_control }
    end
  end
end
