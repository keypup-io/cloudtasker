# frozen_string_literal: true

require 'cloudtasker/backend/memory_task'

RSpec.describe Cloudtasker::Backend::MemoryTask do
  let(:job_payload) do
    {
      http_request: {
        http_method: 'POST',
        url: 'http://localhost:300/run',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer 123'
        },
        body: {
          worker: worker_name,
          job_id: 'aaa'
        }.to_json
      },
      schedule_time: 2,
      queue: 'critical'
    }
  end
  let(:job_payload2) do
    {
      http_request: {
        http_method: 'POST',
        url: 'http://localhost:300/run',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer 123'
        },
        body: {
          worker: worker_name2,
          job_id: 'bbb'
        }.to_json
      },
      schedule_time: 2
    }
  end
  let(:worker_name) { 'TestWorker' }
  let(:worker_name2) { 'TestWorker2' }
  let(:task_id) { '1234' }
  let(:task) { described_class.new(**job_payload.merge(id: task_id)) }
  let(:task_id2) { '2434' }
  let(:task2) { described_class.new(**job_payload2.merge(id: task_id2)) }

  before { described_class.clear }

  describe '.inline_mode?' do
    subject { described_class }

    before { allow(Cloudtasker::Testing).to receive(:inline?).and_return(enabled) }

    context 'with testing inline! mode enabled' do
      let(:enabled) { true }

      it { is_expected.to be_inline_mode }
    end

    context 'with testing inline! mode disabled' do
      let(:enabled) { false }

      it { is_expected.not_to be_inline_mode }
    end
  end

  describe '.queue' do
    subject { described_class.queue }

    it { is_expected.to be_a(Array) }
  end

  describe '.drain' do
    subject { described_class.drain(filter) }

    let(:filter) { 'somefilter' }
    let(:resp) { 'some-respone' }

    before { allow(described_class).to receive(:all).with(filter).and_return([task]) }
    before { allow(task).to receive(:execute).and_return(resp) }
    it { is_expected.to eq([resp]) }
  end

  describe '.all' do
    subject { described_class.all(filter) }

    let(:filter) { nil }

    before { described_class.create(job_payload.merge(id: task_id)) }
    before { described_class.create(job_payload2.merge(id: task_id2)) }

    context 'without filter' do
      it { is_expected.to eq([task, task2]) }
    end

    context 'with filter' do
      let(:filter) { worker_name }

      it { is_expected.to eq([task]) }
    end
  end

  describe '.create' do
    subject { described_class.queue.first }

    let(:create_task) { described_class.create(job_payload.merge(id: task_id)) }

    context 'without inline_mode' do
      let(:expected_attrs) do
        job_payload.merge(id: task_id, schedule_time: Time.at(job_payload[:schedule_time]))
      end

      before { create_task }
      it { is_expected.to have_attributes(expected_attrs) }
    end

    context 'with inline_mode' do
      let(:task) { instance_double(described_class, id: task_id) }
      let(:expected_attrs) { job_payload.merge(id: task_id) }

      before do
        allow(described_class).to receive(:inline_mode?).and_return(true)
        allow(described_class).to receive(:new).with(expected_attrs).and_return(task)
        expect(task).to receive(:execute)
        create_task
      end
      it { is_expected.to eq(task) }
    end
  end

  describe '.find' do
    subject { described_class.find(task_id) }

    let(:filter) { nil }

    before { described_class.create(job_payload.merge(id: task_id)) }
    before { described_class.create(job_payload2.merge(id: task_id2)) }
    it { is_expected.to eq(task) }
  end

  describe '.delete' do
    subject { described_class.queue }

    let(:filter) { nil }

    before { described_class.create(job_payload.merge(id: task_id)) }
    before { described_class.create(job_payload2.merge(id: task_id2)) }
    before { described_class.delete(task_id) }
    it { is_expected.to eq([task2]) }
  end

  describe '.clear' do
    subject { described_class.queue }

    before { described_class.create(job_payload.merge(id: task_id)) }
    before { described_class.create(job_payload2.merge(id: task_id2)) }
    before { described_class.clear }
    it { is_expected.to be_empty }
  end

  describe '.new' do
    subject { described_class.new(**job_payload.merge(id: id)) }

    let(:id) { '123' }
    let(:expected_attrs) do
      job_payload.merge(id: id, schedule_time: Time.at(job_payload[:schedule_time]))
    end

    it { is_expected.to have_attributes(expected_attrs) }
  end

  describe '#payload' do
    subject { task.payload }

    it { is_expected.to eq(JSON.parse(job_payload.dig(:http_request, :body), symbolize_names: true)) }
  end

  describe '#worker_class_name' do
    subject { task.worker_class_name }

    it { is_expected.to eq(worker_name) }
  end

  describe '#to_h' do
    subject { task.to_h }

    let(:expected_hash) do
      {
        id: task.id,
        http_request: task.http_request,
        schedule_time: task.schedule_time.to_i,
        queue: task.queue
      }
    end

    it { is_expected.to eq(expected_hash) }
  end

  describe '#execute' do
    subject(:execute) { task.execute }

    let(:worker) { TestWorker.new }
    let(:resp) { 'some-response' }
    let(:worker_payload) { task.payload.merge(job_retries: task.job_retries, task_id: task.id) }

    before do
      allow(Cloudtasker::WorkerHandler).to receive(:with_worker_handling).with(worker_payload).and_yield(worker)
      allow(worker).to receive(:execute).and_return(resp)
      allow(described_class).to receive(:delete).with(task_id)
    end

    context 'with success' do
      it { is_expected.to eq(resp) }
    end

    context 'with dead worker and inline_mode' do
      before { allow(described_class).to receive(:inline_mode?).and_return(true) }
      before { allow(worker).to receive(:execute).and_raise(Cloudtasker::DeadWorkerError) }
      after { expect(described_class).to have_received(:delete) }
      after { expect(task).to have_attributes(job_retries: 0) }
      it { expect { execute }.to raise_error(Cloudtasker::DeadWorkerError) }
    end

    context 'with error and no inline_mode' do
      before { allow(described_class).to receive(:inline_mode?).and_return(false) }
      before { allow(worker).to receive(:execute).and_raise(Cloudtasker::DeadWorkerError) }
      after { expect(described_class).to have_received(:delete) }
      after { expect(task).to have_attributes(job_retries: 0) }
      it { expect { execute }.not_to raise_error }
    end

    context 'with error and inline_mode' do
      before { allow(described_class).to receive(:inline_mode?).and_return(true) }
      before { allow(worker).to receive(:execute).and_raise(StandardError) }
      after { expect(described_class).not_to have_received(:delete) }
      after { expect(task).to have_attributes(job_retries: 1) }
      it { expect { execute }.to raise_error(StandardError) }
    end

    context 'with error and no inline_mode' do
      before { allow(described_class).to receive(:inline_mode?).and_return(false) }
      before { allow(worker).to receive(:execute).and_raise(StandardError) }
      after { expect(described_class).not_to have_received(:delete) }
      after { expect(task).to have_attributes(job_retries: 1) }
      it { expect { execute }.not_to raise_error }
    end
  end

  describe '#==' do
    subject { task }

    context 'with same id' do
      it { is_expected.to eq(described_class.new(**job_payload.merge(id: task_id))) }
    end

    context 'with different id' do
      it { is_expected.not_to eq(described_class.new(**job_payload.merge(id: task_id + 'a'))) }
    end

    context 'with different object' do
      it { is_expected.not_to eq('foo') }
    end
  end
end
