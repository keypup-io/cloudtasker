# frozen_string_literal: true

require 'cloudtasker/worker_wrapper'

RSpec.describe Cloudtasker::WorkerWrapper do
  let(:worker_class) { 'TestWorker' }

  describe '.ancestors' do
    subject { described_class.ancestors }

    it { is_expected.to include(Cloudtasker::Worker) }
  end

  describe '.new' do
    subject { described_class.new(**worker_args.merge(worker_name: worker_class)) }

    let(:id) { SecureRandom.uuid }
    let(:args) { [1, 2] }
    let(:meta) { { foo: 'bar' } }
    let(:retries) { 3 }
    let(:queue) { 'critical' }
    let(:worker_args) { { job_queue: queue, job_args: args, job_id: id, job_meta: meta, job_retries: retries } }
    let(:expected_args) do
      {
        job_queue: queue,
        job_args: args,
        job_id: id,
        job_meta: eq(meta),
        job_retries: retries,
        worker_name: worker_class
      }
    end

    it { is_expected.to have_attributes(expected_args) }
  end

  describe '#job_class_name' do
    subject { described_class.new(worker_name: worker_class).job_class_name }

    it { is_expected.to eq(worker_class) }
  end

  describe '#new_instance' do
    subject(:new_instance) { worker.new_instance }

    let(:job_args) { [1, 2] }
    let(:job_meta) { { foo: 'bar' } }
    let(:job_queue) { 'critical' }
    let(:attrs) { { worker_name: worker_class, job_queue: job_queue, job_args: job_args, job_meta: job_meta } }
    let(:worker) { described_class.new(**attrs) }

    it { is_expected.to have_attributes(attrs.merge(job_meta: eq(job_meta))) }
    it { expect(new_instance.job_id).not_to eq(worker.job_id) }
  end
end
