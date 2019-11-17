# frozen_string_literal: true

RSpec.describe Cloudtasker::Worker do
  let(:worker_class) { TestWorker }

  describe '.from_json' do
    subject { described_class.from_json(serialized_worker) }

    let(:worker_hash) { { 'foo' => 'bar' } }
    let(:serialized_worker) { worker_hash.to_json }
    let(:worker) { instance_double('TestWorker') }

    before { allow(described_class).to receive(:from_hash).with(worker_hash).and_return(worker) }

    context 'with valid json' do
      it { is_expected.to eq(worker) }
    end

    context 'with invalid json' do
      let(:serialized_worker) { '-' }

      it { is_expected.to be_nil }
    end
  end

  describe '.from_hash' do
    subject { described_class.from_hash(worker_hash) }

    let(:job_id) { '123' }
    let(:job_args) { [1, 2] }
    let(:job_meta) { { foo: 'bar' } }
    let(:worker_class_name) { worker_class.to_s }
    let(:worker_hash) do
      {
        worker: worker_class_name,
        job_id: job_id,
        job_args: job_args,
        job_meta: job_meta
      }
    end

    context 'with valid worker' do
      it { is_expected.to be_a(worker_class) }
      it { is_expected.to have_attributes(job_id: job_id, job_args: job_args, job_meta: eq(job_meta)) }
    end

    context 'with invalid worker' do
      let(:worker_class) { TestNonWorker }

      it { is_expected.to be_nil }
    end

    context 'with invalid class' do
      let(:worker_class_name) { 'Foo' }

      it { is_expected.to be_nil }
    end
  end

  describe '.perform_at' do
    subject { worker_class.perform_at(time_at, arg1, arg2) }

    let(:time_at) { Time.now }
    let(:arg1) { 1 }
    let(:arg2) { 2 }
    let(:task) { instance_double('Cloudtasker::Task') }
    let(:resp) { instance_double('Google::Cloud::Tasks::V2beta3::Task') }
    let(:worker) { instance_double(worker_class.to_s) }

    before do
      allow(worker_class).to receive(:new).with(job_args: [arg1, arg2]).and_return(worker)
      allow(worker).to receive(:schedule).with(time_at: time_at).and_return(resp)
    end

    it { is_expected.to eq(resp) }
  end

  describe '.perform_in' do
    subject { worker_class.perform_in(delay, arg1, arg2) }

    let(:delay) { 10 }
    let(:arg1) { 1 }
    let(:arg2) { 2 }
    let(:task) { instance_double('Cloudtasker::Task') }
    let(:resp) { instance_double('Google::Cloud::Tasks::V2beta3::Task') }
    let(:worker) { instance_double(worker_class.to_s) }

    before do
      allow(worker_class).to receive(:new).with(job_args: [arg1, arg2]).and_return(worker)
      allow(worker).to receive(:schedule).with(interval: delay).and_return(resp)
    end

    it { is_expected.to eq(resp) }
  end

  describe '.perform_async' do
    subject { worker_class.perform_async(arg1, arg2) }

    let(:arg1) { 1 }
    let(:arg2) { 2 }
    let(:resp) { instance_double('Google::Cloud::Tasks::V2beta3::Task') }

    before { allow(worker_class).to receive(:perform_in).with(nil, arg1, arg2).and_return(resp) }
    it { is_expected.to eq(resp) }
  end

  describe '.cloudtasker_options_hash' do
    subject { worker_class.cloudtasker_options_hash }

    let(:opts) { { foo: 'bar' } }
    let!(:original_opts) { worker_class.cloudtasker_options_hash }

    before { worker_class.cloudtasker_options(opts) }
    after { worker_class.cloudtasker_options(original_opts) }
    it { is_expected.to eq(Hash[opts.map { |k, v| [k.to_s, v] }]) }
  end

  describe '.new' do
    subject { worker_class.new(worker_args) }

    let(:id) { SecureRandom.uuid }
    let(:args) { [1, 2] }
    let(:meta) { { foo: 'bar' } }

    context 'without args' do
      let(:worker_args) { {} }

      it { is_expected.to have_attributes(job_args: [], job_id: be_present) }
    end

    context 'with args' do
      let(:worker_args) { { job_args: args, job_id: id, job_meta: meta } }

      it { is_expected.to have_attributes(job_args: args, job_id: id, job_meta: eq(meta)) }
    end
  end

  describe '#schedule' do
    subject { worker.schedule(interval: delay, time_at: time_at) }

    let(:time_at) { Time.now }
    let(:delay) { 10 }
    let(:arg1) { 1 }
    let(:arg2) { 2 }
    let(:task) { instance_double('Cloudtasker::Task') }
    let(:resp) { instance_double('Google::Cloud::Tasks::V2beta3::Task') }
    let(:worker) { worker_class.new(job_args: [1, 2]) }

    before do
      allow(Cloudtasker::Task).to receive(:new).with(worker).and_return(task)
      allow(task).to receive(:schedule).with(interval: delay, time_at: time_at).and_return(resp)
    end

    it { is_expected.to eq(resp) }

    context 'with client middleware chain' do
      before { Cloudtasker.config.client_middleware.add(TestMiddleware) }
      after { expect(worker.middleware_called).to be_truthy }
      it { is_expected.to eq(resp) }
    end
  end

  describe '#execute' do
    subject { worker.execute }

    let(:worker) { worker_class.new(job_args: args, job_id: SecureRandom.uuid) }
    let(:args) { [1, 2] }
    let(:resp) { 'some-result' }

    before { allow(worker).to receive(:perform).with(*args).and_return(resp) }

    it { is_expected.to eq(resp) }

    context 'with server middleware chain' do
      before { Cloudtasker.config.server_middleware.add(TestMiddleware) }
      after { expect(worker.middleware_called).to be_truthy }
      it { is_expected.to eq(resp) }
    end
  end

  describe '#reenqueue' do
    subject { worker.reenqueue(delay) }

    let(:delay) { 10 }
    let(:worker) { worker_class.new(job_args: args) }
    let(:args) { [1, 2] }

    let(:resp) { instance_double('Google::Cloud::Tasks::V2beta3::Task') }

    before { allow(worker).to receive(:schedule).with(interval: delay).and_return(resp) }
    after { expect(worker.job_reenqueued).to be_truthy }
    it { is_expected.to eq(resp) }
  end

  describe '#new_instance' do
    subject(:new_instance) { worker.new_instance }

    let(:job_args) { [1, 2] }
    let(:job_meta) { { foo: 'bar' } }
    let(:worker) { worker_class.new(job_args: job_args, job_meta: job_meta) }

    it { is_expected.to have_attributes(job_args: job_args, job_meta: eq(job_meta)) }
    it { expect(new_instance.job_id).not_to eq(worker.job_id) }
  end

  describe '#to_h' do
    subject { worker.to_h }

    let(:job_args) { [1, 2] }
    let(:job_meta) { { foo: 'bar' } }
    let(:worker) { worker_class.new(job_args: job_args, job_meta: job_meta) }
    let(:expected_hash) do
      {
        worker: worker.class.to_s,
        job_id: worker.job_id,
        job_args: worker.job_args,
        job_meta: worker.job_meta
      }
    end

    it { is_expected.to eq(expected_hash) }
  end

  describe '#to_json' do
    subject { worker.to_json }

    let(:worker) { worker_class.new(job_args: [1, 2], job_meta: { foo: 'bar' }) }

    it { is_expected.to eq(worker.to_h.to_json) }
  end
end
