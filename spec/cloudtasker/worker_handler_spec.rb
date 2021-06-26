# frozen_string_literal: true

RSpec.describe Cloudtasker::WorkerHandler do
  let(:config) { Cloudtasker.config }
  let(:worker) { TestWorker.new(job_args: job_args, job_meta: job_meta) }
  let(:job_args) { ['foo', 1] }
  let(:job_meta) { { foo: 'bar' } }
  let(:job_id) { nil }
  let(:task) { described_class.new(worker) }

  describe '.new' do
    subject { task }

    it { is_expected.to have_attributes(worker: worker) }
  end

  describe '#key' do
    subject { described_class.key(val) }

    let(:val) { 'foo' }
    let(:resp) { 'bar' }

    before { allow(described_class).to receive(:key).with(val).and_return(resp) }
    it { is_expected.to eq(resp) }
  end

  describe '.redis' do
    subject { described_class.redis }

    it { is_expected.to be_a(Cloudtasker::RedisClient) }
  end

  describe '.log_execution_error' do
    subject { described_class.log_execution_error(worker, error) }

    let(:worker) { instance_double('TestWorker') }
    let(:error) { instance_double('ArgumentError', backtrace: %w[1 2 3]) }

    context 'with ActiveJob worker' do
      let(:worker) { ActiveJob::QueueAdapters::CloudtaskerAdapter::JobWrapper.new }

      before do
        expect(worker).not_to receive(:logger)
        expect(Cloudtasker).not_to receive(:logger)
      end

      it { is_expected.to be_nil }
    end

    context 'with no worker' do
      let(:worker) { nil }
      let(:logger) { instance_double('ActiveSupport::Logger') }

      before do
        allow(Cloudtasker).to receive(:logger).and_return(logger)
        expect(logger).to receive(:error).with(error).and_return(true)
      end

      it { is_expected.to be_truthy }
    end

    context 'with worker' do
      let(:logger) { instance_double('Cloudtasker::WorkerLogger') }

      before do
        allow(worker).to receive(:logger).and_return(logger)
        expect(logger).to receive(:error).with(error).and_return(true)
      end

      it { is_expected.to be_truthy }
    end
  end

  describe '.extract_payload' do
    subject { described_class.extract_payload(input_payload) }

    context 'with redis payload and successful yield' do
      let(:args_payload_id) { '111' }
      let(:args_payload_key) do
        described_class.key([described_class::REDIS_PAYLOAD_NAMESPACE, args_payload_id].join('/'))
      end
      let(:args_payload) { [1, 2] }
      let(:input_payload) do
        {
          'worker' => 'TestWorker',
          'job_id' => 'some-id',
          'job_args_payload_id' => args_payload_id
        }
      end
      let(:actual_payload) { { worker: 'TestWorker', job_id: 'some-id', job_args: args_payload } }
      let(:extracted_payload) { { args_payload_key: args_payload_key, payload: actual_payload } }

      before { described_class.redis.write(args_payload_key, args_payload) }
      it { is_expected.to eq(extracted_payload) }
    end

    context 'with native payload' do
      let(:input_payload) { { 'worker' => 'TestWorker', 'job_id' => 'some-id', 'job_args' => [1, 2] } }
      let(:actual_payload) { { worker: 'TestWorker', job_id: 'some-id', job_args: [1, 2] } }
      let(:extracted_payload) { { args_payload_key: nil, payload: actual_payload } }

      it { is_expected.to eq(extracted_payload) }
    end
  end

  describe '.with_worker_handling' do
    let(:subject_block) { expect { |b| described_class.with_worker_handling(input_payload, &(block || b)) } }
    let(:block) { nil }

    let(:args_payload_id) { '111' }
    let(:args_payload_key) do
      described_class.key([described_class::REDIS_PAYLOAD_NAMESPACE, args_payload_id].join('/'))
    end
    let(:args_payload) { [1, 2] }
    let(:input_payload) do
      {
        'worker' => 'TestWorker',
        'job_id' => 'some-id',
        'job_args_payload_id' => args_payload_id
      }
    end
    let(:extracted_payload) { { job_id: 'some-id', job_args: args_payload } }
    let(:args_key_content) { described_class.redis.get(args_payload_key) }

    context 'with redis payload and successful yield' do
      before { described_class.redis.write(args_payload_key, args_payload) }
      after { expect(args_key_content).to be_blank }
      it { subject_block.to yield_with_args(be_a(Cloudtasker::Worker)) }
      it { subject_block.to yield_with_args(have_attributes(extracted_payload)) }
    end

    context 'with redis payload and reenqueued worker' do
      let(:block) { ->(worker) { worker.job_reenqueued = true } }

      before { described_class.redis.write(args_payload_key, args_payload) }
      after { expect(args_key_content).to be_present }
      it { subject_block.not_to raise_error }
    end

    context 'with redis payload and errored yield' do
      let(:job_error) { StandardError }
      let(:block) { ->(_) { raise(job_error) } }

      before do
        described_class.redis.write(args_payload_key, args_payload)
        expect(Cloudtasker.config.on_error).to receive(:call).with(job_error, be_a(Cloudtasker::Worker))
      end
      after { expect(args_key_content).to be_present }

      it { subject_block.to raise_error(job_error) }
    end

    context 'with redis payload and invalid worker' do
      let(:job_error) { Cloudtasker::InvalidWorkerError }
      let(:block) { ->(_) { raise(job_error) } }

      before do
        described_class.redis.write(args_payload_key, args_payload)
        expect(Cloudtasker.config.on_error).to receive(:call).with(job_error, be_a(Cloudtasker::Worker))
      end
      after { expect(args_key_content).to be_present }
      it { subject_block.to raise_error(job_error) }
    end

    context 'with redis payload and Cloudtasker::DeadWorkerError' do
      let(:job_error) { Cloudtasker::DeadWorkerError }
      let(:block) { ->(_) { raise(job_error) } }

      before do
        described_class.redis.write(args_payload_key, args_payload)
        expect(Cloudtasker.config.on_dead).to receive(:call).with(job_error, be_a(Cloudtasker::Worker))
      end
      after { expect(args_key_content).to be_blank }
      it { subject_block.to raise_error(job_error) }
    end

    context 'with native payload' do
      let(:input_payload) { { 'worker' => 'TestWorker', 'job_id' => 'some-id', 'job_args' => [1, 2] } }
      let(:extracted_payload) { { job_id: 'some-id', job_args: [1, 2] } }

      it { subject_block.to yield_with_args(be_a(Cloudtasker::Worker)) }
      it { subject_block.to yield_with_args(have_attributes(extracted_payload)) }
    end
  end

  describe '.execute_from_payload!' do
    subject(:execute) { described_class.execute_from_payload!(input_payload) }

    let(:input_payload) { { 'foo' => 'bar' } }
    let(:actual_payload) { { 'baz' => 'fooz' } }
    let(:worker) { instance_double('TestWorker') }
    let(:ret) { 'some-result' }

    before { allow(described_class).to receive(:with_worker_handling).with(input_payload).and_yield(worker) }
    before { allow(worker).to receive(:execute).and_return(ret) }

    it { is_expected.to eq(ret) }
  end

  describe '#task_payload' do
    subject { task.task_payload }

    let(:expected_payload) do
      {
        http_request: {
          http_method: 'POST',
          url: config.processor_url,
          headers: {
            'Content-Type' => 'application/json',
            'Authorization' => "Bearer #{Cloudtasker::Authenticator.verification_token}"
          },
          body: task.worker_payload.to_json
        },
        queue: task.worker.job_queue,
        dispatch_deadline: task.worker.dispatch_deadline
      }
    end

    around { |e| Timecop.freeze { e.run } }
    it { is_expected.to eq(expected_payload) }
  end

  describe '#store_payload_in_redis?' do
    subject { task.store_payload_in_redis? }

    let(:threshold) { nil }

    before { allow(Cloudtasker.config).to receive(:redis_payload_storage_threshold).and_return(threshold) }

    context 'with no threshold configured' do
      it { is_expected.to be_falsey }
    end

    context 'with arg payload not exceeding threshold' do
      let(:threshold) { 1000 }

      it { is_expected.to be_falsey }
    end

    context 'with threshold set to zero' do
      let(:threshold) { 0 }

      it { is_expected.to be_truthy }
    end

    context 'with arg payload exceeding threshold' do
      let(:threshold) { 10 }
      let(:job_args) { ['a'] * 2600 }

      it { is_expected.to be_truthy }
    end
  end

  describe '#worker_args_payload' do
    subject { task.worker_args_payload }

    let(:store_payload) { false }
    let(:args_payload_key) { described_class.key([described_class::REDIS_PAYLOAD_NAMESPACE, worker.job_id].join('/')) }

    before { allow(task).to receive(:store_payload_in_redis?).and_return(store_payload) }

    context 'with redis storage not required' do
      after { expect(described_class.redis.fetch(args_payload_key)).to be_nil }
      it { is_expected.to eq(job_args: job_args) }
    end

    context 'with redis storage required' do
      let(:store_payload) { true }

      after { expect(described_class.redis.fetch(args_payload_key)).to eq(job_args) }
      it { is_expected.to eq(job_args_payload_id: worker.job_id) }
    end
  end

  describe '#worker_payload' do
    subject { task.worker_payload }

    let(:class_name) { 'SomeWorker' }
    let(:worker_args_payload) { { job_args: %w[foo bar baz] } }
    let(:expected_payload) do
      {
        worker: class_name,
        job_queue: worker.job_queue,
        job_id: worker.job_id,
        job_meta: job_meta
      }.merge(worker_args_payload)
    end

    before { allow(task).to receive(:worker_args_payload).and_return(worker_args_payload) }
    before { allow(worker).to receive(:job_class_name).and_return(class_name) }
    after { expect(worker).to have_received(:job_class_name) }
    it { is_expected.to eq(expected_payload) }
  end

  describe '#schedule' do
    subject { task.schedule(**attrs) }

    let(:attrs) { {} }
    let(:expected_payload) { task.task_payload }
    let(:resp) { instance_double('Cloudtasker::CloudTask') }

    around { |e| Timecop.freeze { e.run } }
    before { allow(Cloudtasker::CloudTask).to receive(:create).with(expected_payload).and_return(resp) }

    context 'with no delay' do
      it { is_expected.to eq(resp) }
    end

    context 'with scheduled time' do
      let(:attrs) { { time_at: Time.now } }
      let(:expected_payload) { task.task_payload.merge(schedule_time: attrs[:time_at]) }

      it { is_expected.to eq(resp) }
    end
  end
end
