# frozen_string_literal: true

require 'cloudtasker/unique_job/middleware'

RSpec.describe Cloudtasker::UniqueJob::Job do
  let(:worker) { TestWorker.new(job_args: [1, 2]) }
  let(:job) { described_class.new(worker) }

  describe '.new' do
    subject { job }

    it { is_expected.to have_attributes(worker: worker) }
  end

  describe '#options' do
    subject { job.options }

    it { is_expected.to eq(worker.class.cloudtasker_options_hash) }
  end

  describe '#lock_instance' do
    subject { job.lock_instance }

    before { allow(job).to receive(:options).and_return(job_opts) }

    context 'with no lock strategy' do
      let(:job_opts) { {} }

      it { is_expected.to be_a(Cloudtasker::UniqueJob::Lock::NoOp) }
      it { is_expected.to have_attributes(job: job) }
    end

    context 'with invalid lock strategy' do
      let(:job_opts) { {} }

      it { is_expected.to be_a(Cloudtasker::UniqueJob::Lock::NoOp) }
      it { is_expected.to have_attributes(job: job) }
    end

    context 'with valid lock strategy' do
      let(:job_opts) { { lock: 'until_executed' } }

      it { is_expected.to be_a(Cloudtasker::UniqueJob::Lock::UntilExecuted) }
      it { is_expected.to have_attributes(job: job) }
    end
  end

  describe '#unique_args' do
    subject { job.unique_args }

    context 'with unique_args specified on the worker' do
      let(:unique_args) { worker.job_args + ['some-extra-arg'] }

      before { allow(worker).to receive(:unique_args).with(worker.job_args).and_return(unique_args) }
      it { is_expected.to eq(unique_args) }
    end

    context 'with no unique_args specified on the worker' do
      it { is_expected.to eq(worker.job_args) }
    end
  end

  describe '#digest_hash' do
    subject { job.digest_hash }

    it { is_expected.to eq(class: worker.class.to_s, unique_args: job.unique_args) }
  end

  describe '#id' do
    subject { job.id }

    it { is_expected.to eq(worker.job_id) }
  end

  describe '#unique_id' do
    subject { job.unique_id }

    it { is_expected.to eq(Digest::SHA256.hexdigest(job.digest_hash.to_json)) }
  end

  describe '#unique_gid' do
    subject { job.unique_gid }

    it { is_expected.to eq([described_class.to_s.underscore, job.unique_id].join('/')) }
  end

  describe '#redis' do
    subject { job.redis }

    it { is_expected.to be_a(Cloudtasker::RedisClient) }
  end

  describe '#lock!' do
    subject(:lock!) { job.lock! }

    context 'with lock acquired by another job' do
      let(:other_worker) { TestWorker.new(job_args: [1, 2]) }
      let(:other_job) { described_class.new(other_worker) }

      before { other_job.lock! }
      it { expect { lock! }.to raise_error(Cloudtasker::UniqueJob::LockError) }
    end

    context 'with lock acquired by the same job' do
      before { job.lock! }
      it { expect { lock! }.not_to raise_error }
    end

    context 'with lock available' do
      after { expect(job.redis.get(job.unique_gid)).to eq(job.id) }
      it { expect { lock! }.not_to raise_error }
    end
  end

  describe '#unlock!' do
    subject { job.redis.get(job.unique_gid) }

    context 'with lock acquired by another job' do
      let(:other_worker) { TestWorker.new(job_args: [1, 2]) }
      let(:other_job) { described_class.new(other_worker) }

      before { other_job.lock! }
      before { job.unlock! }
      it { is_expected.to eq(other_job.id) }
    end

    context 'with lock acquired by the same job' do
      before { job.lock! }
      before { expect(job.redis.get(job.unique_gid)).to eq(job.id) }
      before { job.unlock! }
      it { is_expected.to be_nil }
    end
  end
end
