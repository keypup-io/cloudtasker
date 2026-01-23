# frozen_string_literal: true

require 'cloudtasker/unique_job/middleware'

RSpec.describe Cloudtasker::UniqueJob::Job do
  let(:worker) { TestWorker.new(job_args: [1, 2]) }
  let(:call_opts) { { time_at: Time.now + 3600 } }
  let(:job) { described_class.new(worker, call_opts) }

  describe '.new' do
    subject { job }

    it { is_expected.to have_attributes(worker: worker, call_opts: call_opts) }
  end

  describe '#options' do
    subject { job.options }

    it { is_expected.to eq(worker.class.cloudtasker_options_hash) }
  end

  describe '#lock_ttl' do
    subject { job.lock_ttl }

    let(:job_opts) { {} }
    let(:call_opts) { {} }
    let(:default_ttl) { Cloudtasker::UniqueJob::DEFAULT_LOCK_TTL }
    let(:now) { Time.now.to_i }

    around { |e| Timecop.freeze { e.run } }
    before { allow(job).to receive(:options).and_return(job_opts) }
    before { allow(job).to receive(:call_opts).and_return(call_opts) }

    context 'with no opts' do
      it { is_expected.to eq(default_ttl) }
    end

    context 'with global lock_ttl' do
      let(:global_ttl) { 30 }

      before { Cloudtasker::UniqueJob.configure { |c| c.lock_ttl = global_ttl } }
      after { Cloudtasker::UniqueJob.configure { |c| c.lock_ttl = nil } }
      it { is_expected.to eq(global_ttl) }
    end

    context 'with call_opts[:time_at]' do
      let(:call_opts) { { time_at: now + 3600 } }

      it { is_expected.to eq(call_opts[:time_at] + default_ttl - now) }
    end

    context 'with options[:lock_ttl]' do
      let(:job_opts) { { lock_ttl: 60 } }

      it { is_expected.to eq(job_opts[:lock_ttl]) }
    end

    context 'with call_opts[:time_at] and options[:lock_ttl]' do
      let(:call_opts) { { time_at: now + 3600 } }
      let(:job_opts) { { lock_ttl: 60 } }

      it { is_expected.to eq(call_opts[:time_at] + job_opts[:lock_ttl] - now) }
    end

    context 'with call_opts[:time_at] in the past' do
      let(:call_opts) { { time_at: now - 3600 } }

      it { is_expected.to eq(default_ttl) }
    end

    context 'with call_opts[:time_at] in the past and custom lock_ttl' do
      let(:call_opts) { { time_at: now - 3600 } }
      let(:job_opts) { { lock_ttl: 60 } }

      it { is_expected.to eq(job_opts[:lock_ttl]) }
    end
  end

  describe '#lock_provisional_ttl' do
    subject { job.lock_provisional_ttl }

    let(:job_opts) { {} }
    let(:default_provisional_ttl) { Cloudtasker::UniqueJob::DEFAULT_LOCK_PROVISIONAL_TTL }

    before { allow(job).to receive(:options).and_return(job_opts) }

    context 'with no opts' do
      it { is_expected.to eq(default_provisional_ttl) }
    end

    context 'with global lock_provisional_ttl' do
      let(:global_provisional_ttl) { 5 }

      before { Cloudtasker::UniqueJob.configure { |c| c.lock_provisional_ttl = global_provisional_ttl } }
      after { Cloudtasker::UniqueJob.configure { |c| c.lock_provisional_ttl = nil } }
      it { is_expected.to eq(global_provisional_ttl) }
    end

    context 'with options[:lock_provisional_ttl]' do
      let(:job_opts) { { lock_provisional_ttl: 10 } }

      it { is_expected.to eq(job_opts[:lock_provisional_ttl]) }
    end
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
      let(:job_opts) { { lock: 'foo' } }

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
      after { expect(job.redis.ttl(job.unique_gid)).to be_within(10).of(job.lock_ttl) }
      it { expect { lock! }.not_to raise_error }
    end
  end

  describe '#lock_for_scheduling!' do
    let(:block_executed) { [] }

    context 'with lock acquired by another job' do
      let(:other_worker) { TestWorker.new(job_args: [1, 2]) }
      let(:other_job) { described_class.new(other_worker) }

      before { other_job.lock! }
      it 'raises a LockError' do
        expect do
          job.lock_for_scheduling! do
            block_executed << true
          end
        end.to raise_error(Cloudtasker::UniqueJob::LockError)
      end
    end

    context 'with lock available' do
      it 'acquires provisional lock, yields, then sets final lock' do
        expect { job.lock_for_scheduling! { block_executed << true } }.not_to raise_error
        expect(block_executed).to eq([true])
        expect(job.redis.get(job.unique_gid)).to eq(job.id)
        expect(job.redis.ttl(job.unique_gid)).to be_within(10).of(job.lock_ttl)
      end

      it 'returns the block return value' do
        result = job.lock_for_scheduling! { 'test_result' }
        expect(result).to eq('test_result')
      end
    end

    context 'with lock already acquired by the same job' do
      before { job.lock! }

      it 'refreshes provisional lock, yields, then sets final lock' do
        expect { job.lock_for_scheduling! { block_executed << true } }.not_to raise_error
        expect(block_executed).to eq([true])
        expect(job.redis.get(job.unique_gid)).to eq(job.id)
        expect(job.redis.ttl(job.unique_gid)).to be_within(10).of(job.lock_ttl)
      end
    end

    context 'when provisional lock expires before final lock' do
      it 'does not raise an error' do
        expect do
          job.lock_for_scheduling! do
            block_executed << true
            # Simulate provisional lock expiring
            job.redis.del(job.unique_gid)
          end
        end.not_to raise_error

        expect(block_executed).to eq([true])
      end
    end

    context 'when provisional lock is taken by another job before final lock' do
      let(:other_worker) { TestWorker.new(job_args: [1, 2]) }
      let(:other_job) { described_class.new(other_worker) }

      it 'does not raise an error' do
        expect do
          job.lock_for_scheduling! do
            block_executed << true
            # Simulate another job taking the lock
            job.redis.del(job.unique_gid)
            other_job.lock!
          end
        end.not_to raise_error

        expect(block_executed).to eq([true])
      end
    end

    context 'when block raises an error' do
      let(:error) { StandardError.new('test error') }

      it 'propagates the error without setting final lock' do
        expect do
          job.lock_for_scheduling! { raise error }
        end.to raise_error(error)

        # Provisional lock should still be set
        expect(job.redis.get(job.unique_gid)).to eq(job.id)
        expect(job.redis.ttl(job.unique_gid)).to be_within(2).of(job.lock_provisional_ttl)
      end
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
