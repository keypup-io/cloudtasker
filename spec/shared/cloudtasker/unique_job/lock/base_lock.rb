# frozen_string_literal: true

require 'cloudtasker/unique_job/middleware'

RSpec.shared_examples Cloudtasker::UniqueJob::Lock::BaseLock do
  let(:worker) { TestWorker.new(job_args: [1, 2]) }
  let(:job) { Cloudtasker::UniqueJob::Job.new(worker) }
  let(:lock) { described_class.new(job) }

  describe '.new' do
    subject { lock }

    it { is_expected.to have_attributes(job: job) }
  end

  describe '#default_conflict_strategy' do
    subject { lock.default_conflict_strategy }

    it { is_expected.to be < Cloudtasker::UniqueJob::ConflictStrategy::BaseStrategy }
  end

  describe '#options' do
    subject { lock.options }

    it { is_expected.to eq(job.options) }
  end

  describe '#conflict_instance' do
    subject { lock.conflict_instance }

    before { allow(lock).to receive(:options).and_return(job_opts) }

    context 'with no conflict strategy' do
      let(:job_opts) { {} }

      it { is_expected.to be_a(lock.default_conflict_strategy) }
      it { is_expected.to have_attributes(job: job) }
    end

    context 'with invalid conflict strategy' do
      let(:job_opts) { { on_conflict: 'foo' } }

      it { is_expected.to be_a(lock.default_conflict_strategy) }
      it { is_expected.to have_attributes(job: job) }
    end

    context 'with valid lock strategy' do
      let(:job_opts) { { on_conflict: 'reschedule' } }

      it { is_expected.to be_a(Cloudtasker::UniqueJob::ConflictStrategy::Reschedule) }
      it { is_expected.to have_attributes(job: job) }
    end
  end
end
