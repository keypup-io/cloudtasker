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

  describe '.execute_from_payload!' do
    subject(:execute) { described_class.execute_from_payload!(payload) }

    let(:payload) { { 'foo' => 'bar' } }

    before { allow(Cloudtasker::Worker).to receive(:from_hash).with(payload).and_return(worker) }

    context 'with valid worker' do
      let(:worker) { instance_double('TestWorker') }
      let(:ret) { 'some-result' }

      before { allow(worker).to receive(:execute).and_return(ret) }
      it { is_expected.to eq(ret) }
    end

    context 'with invalid worker' do
      let(:worker) { nil }

      it { expect { execute }.to raise_error(Cloudtasker::InvalidWorkerError) }
    end
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
        queue: task.worker.job_queue
      }
    end

    around { |e| Timecop.freeze { e.run } }
    it { is_expected.to eq(expected_payload) }
  end

  describe '#worker_payload' do
    subject { task.worker_payload }

    let(:class_name) { 'SomeWorker' }
    let(:expected_payload) do
      {
        worker: class_name,
        job_queue: worker.job_queue,
        job_id: worker.job_id,
        job_args: job_args,
        job_meta: job_meta
      }
    end

    before { allow(worker).to receive(:job_class_name).and_return(class_name) }
    after { expect(worker).to have_received(:job_class_name) }
    it { is_expected.to eq(expected_payload) }
  end

  describe '#schedule_time' do
    subject { task.schedule_time(interval: interval, time_at: time_at) }

    let(:interval) { nil }
    let(:time_at) { nil }

    context 'with no args' do
      it { is_expected.to be_nil }
    end

    context 'with interval' do
      let(:interval) { 10 }
      let(:expected_time) { Time.now.to_i + interval }

      around { |e| Timecop.freeze { e.run } }
      it { is_expected.to eq(expected_time) }
    end

    context 'with time_at' do
      let(:time_at) { Time.now }

      it { is_expected.to eq(time_at.to_i) }
    end

    context 'with time_at and interval' do
      let(:time_at) { Time.now }
      let(:interval) { 50 }
      let(:expected_time) { time_at.to_i + interval }

      it { is_expected.to eq(expected_time) }
    end
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
      let(:attrs) { { interval: 10, time_at: Time.now } }
      let(:expected_payload) { task.task_payload.merge(schedule_time: task.schedule_time(attrs)) }

      it { is_expected.to eq(resp) }
    end
  end
end
