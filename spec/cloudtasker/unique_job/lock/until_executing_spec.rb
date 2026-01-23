# frozen_string_literal: true

require 'cloudtasker/unique_job/middleware'

RSpec.describe Cloudtasker::UniqueJob::Lock::UntilExecuting do
  let(:worker) { TestWorker.new(job_args: [1, 2]) }
  let(:job) { Cloudtasker::UniqueJob::Job.new(worker) }
  let(:lock) { described_class.new(job) }

  it_behaves_like Cloudtasker::UniqueJob::Lock::BaseLock

  describe '#schedule' do
    context 'with lock available' do
      before { allow(job).to receive(:lock_for_scheduling!).and_yield }
      it { expect { |b| lock.schedule(&b) }.to yield_control }
    end

    context 'with lock acquired by another job' do
      before { allow(job).to receive(:lock_for_scheduling!).and_raise(Cloudtasker::UniqueJob::LockError) }
      before { allow(lock.conflict_instance).to receive(:on_schedule) }
      after { expect(lock.conflict_instance).to have_received(:on_schedule) { |&b| expect(b).to be_a(Proc) } }
      it { expect { |b| lock.schedule(&b) }.not_to yield_control }
    end

    context 'with runtime error during scheduling' do
      let(:error) { StandardError.new('scheduling error') }

      before { allow(job).to receive(:lock_for_scheduling!).and_raise(error) }
      before { allow(job).to receive(:unlock!) }
      after { expect(job).to have_received(:unlock!) }
      it { expect { lock.schedule { 'test' } }.to raise_error(error) }
    end
  end

  describe '#execute' do
    before { allow(job).to receive(:unlock!) }
    after { expect(job).to have_received(:unlock!) }
    it { expect { |b| lock.execute(&b) }.to yield_control }
  end
end
