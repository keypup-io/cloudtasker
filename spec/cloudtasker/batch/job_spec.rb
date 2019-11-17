# frozen_string_literal: true

require 'cloudtasker/batch/middleware'

RSpec.describe Cloudtasker::Batch::Job do
  let(:worker) { TestWorker.new(job_args: [1, 2]) }
  let(:batch) { described_class.new(worker) }

  let(:child_worker) { worker.new_instance.tap { |e| e.job_meta.set(described_class.key(:parent_id), batch.batch_id) } }
  let(:child_batch) { described_class.new(child_worker) }

  describe '.new' do
    subject { described_class.new(worker) }

    it { is_expected.to have_attributes(worker: worker) }
  end

  describe '.redis' do
    subject { described_class.redis }

    it { is_expected.to eq(Cloudtasker::RedisClient) }
  end

  describe '.for' do
    subject(:batch) { described_class.for(worker) }

    after { expect(worker.batch).to eq(batch) }
    it { is_expected.to be_a(described_class) }
    it { is_expected.to have_attributes(worker: worker) }
  end

  describe '.key' do
    subject { described_class.key(val) }

    context 'with value' do
      let(:val) { :some_key }

      it { is_expected.to eq([described_class.to_s.underscore, val.to_s].join('/')) }
    end

    context 'with nil' do
      let(:val) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe '.find' do
    subject { described_class.find(batch_id) }

    let(:batch_id) { batch.batch_id }

    context 'with existing batch' do
      before { batch.save }

      it { is_expected.to be_a(described_class) }
      it { is_expected.to have_attributes(worker: eq(worker)) }
    end

    context 'with invalid batch id' do
      let(:batch_id) { worker.job_id + 'aaa' }

      it { is_expected.to be_nil }
    end
  end

  describe '#reenqueued?' do
    subject { batch }

    context 'with job reenqueued' do
      before { worker.job_reenqueued = true }

      it { is_expected.to be_reenqueued }
    end

    context 'with job new/enqueued' do
      it { is_expected.not_to be_reenqueued }
    end
  end

  describe '#redis' do
    subject { batch.redis }

    it { is_expected.to eq(Cloudtasker::RedisClient) }
  end

  describe '#key' do
    subject { batch.key(val) }

    let(:val) { 'foo' }
    let(:resp) { 'bar' }

    before { allow(described_class).to receive(:key).with(val).and_return(resp) }
    it { is_expected.to eq(resp) }
  end

  describe '#==' do
    subject { batch }

    context 'with same batch_id' do
      it { is_expected.to eq(described_class.new(worker)) }
    end

    context 'with different job_id' do
      it { is_expected.not_to eq(described_class.new(child_worker)) }
    end

    context 'with different object' do
      it { is_expected.not_to eq('foo') }
    end
  end

  describe '#parent_batch' do
    subject { child_batch.parent_batch }

    context 'with parent batch' do
      before { batch.save }

      it { is_expected.to eq(batch) }
    end

    context 'with no parent batch' do
      it { is_expected.to be_nil }
    end
  end

  describe '#batch_id' do
    subject { batch.batch_id }

    it { is_expected.to eq(worker.job_id) }
  end

  describe '#batch_gid' do
    subject { batch.batch_gid }

    it { is_expected.to eq(described_class.key(batch.batch_id)) }
  end

  describe 'batch_state_gid' do
    subject { batch.batch_state_gid }

    it { is_expected.to eq([batch.batch_gid, 'state'].join('/')) }
  end

  describe '#jobs' do
    subject { batch.jobs }

    context 'with jobs added' do
      subject { batch.jobs[0] }

      let(:meta_batch_id) { batch.jobs[0].job_meta.get(batch.key(:parent_id)) }

      before { batch.add(child_worker.class, *child_worker.job_args) }
      it { is_expected.to be_a(child_worker.class) }
      it { is_expected.to have_attributes(job_args: child_worker.job_args) }
      it { expect(meta_batch_id).to eq(batch.batch_id) }
    end

    context 'with no jobs' do
      it { is_expected.to eq([]) }
    end
  end

  describe '#batch_state' do
    subject { batch.batch_state }

    describe 'with state' do
      before { batch.add(child_worker.class, *child_worker.job_args) }
      before { batch.save }
      it { is_expected.to eq(batch.jobs[0].job_id.to_sym => 'scheduled') }
    end

    describe 'with no state' do
      it { is_expected.to be_nil }
    end
  end

  describe '#add' do
    subject { batch.jobs[0] }

    let(:meta_batch_id) { batch.jobs[0].job_meta.get(batch.key(:parent_id)) }

    before { batch.add(child_worker.class, *child_worker.job_args) }
    it { is_expected.to be_a(child_worker.class) }
    it { is_expected.to have_attributes(job_args: child_worker.job_args) }
    it { expect(meta_batch_id).to eq(batch.batch_id) }
  end

  describe '#save' do
    let(:batch_content) { described_class.redis.fetch(batch.batch_gid) }
    let(:batch_state) { described_class.redis.fetch(batch.batch_state_gid) }

    before { batch.add(child_worker.class, *child_worker.job_args) }
    before { batch.save }

    it { expect(batch_content).to eq(worker.to_h) }
    it { expect(batch_state).to eq(batch.jobs[0].job_id.to_sym => 'scheduled') }
  end

  describe '#setup' do
    subject { batch.setup }

    before { allow(batch).to receive(:save) }
    before { allow(child_worker).to receive(:schedule).and_return(true) }

    context 'with no jobs' do
      after { expect(batch).not_to have_received(:save) }
      after { expect(child_worker).not_to have_received(:schedule) }
      it { is_expected.to be_truthy }
    end

    context 'with jobs on the batch' do
      before { batch.jobs.push(child_worker) }
      after { expect(batch).to have_received(:save) }
      after { expect(child_worker).to have_received(:schedule) }
      it { is_expected.to be_truthy }
    end
  end

  describe '#update_state' do
    subject { batch.batch_state&.dig(child_id.to_sym) }

    let(:child_id) { child_batch.batch_id }
    let(:status) { 'processing' }

    before { batch.jobs.push(child_worker) }
    before { batch.save }
    before { batch.update_state(child_id, status) }

    context 'with existing child batch' do
      it { is_expected.to eq(status) }
    end

    context 'with child batch not attached to the batch' do
      let(:child_id) { 'some-non-existing-id' }

      it { is_expected.to be_nil }
    end
  end

  describe '#complete?' do
    subject { batch }

    before { batch.jobs.push(child_worker) }
    before { batch.save }
    before { batch.update_state(child_batch.batch_id, status) }

    context 'with all jobs completed' do
      let(:status) { 'completed' }

      it { is_expected.to be_complete }
    end

    context 'with some jobs pending' do
      let(:status) { 'processing' }

      it { is_expected.not_to be_complete }
    end
  end

  describe '#on_child_complete' do
    subject { batch.on_child_complete(child_batch) }

    let(:complete) { true }
    let(:parent_batch) { instance_double(described_class.to_s) }

    before { allow(batch).to receive(:complete?).and_return(complete) }
    before { allow(batch).to receive(:parent_batch).and_return(parent_batch) }
    before { allow(batch).to receive(:update_state).with(child_batch.batch_id, :completed) }
    before { allow(worker).to receive(:on_child_complete).with(child_batch.worker) }
    before { parent_batch && allow(parent_batch).to(receive(:on_child_complete).with(batch)).and_return(true) }
    before { batch.jobs.push(child_worker) }
    before { batch.save }

    context 'with batch complete' do
      after { expect(batch).to have_received(:update_state) }
      after { expect(worker).to have_received(:on_child_complete) }
      after { expect(parent_batch).to have_received(:on_child_complete) }
      it { is_expected.to be_truthy }
    end

    context 'with batch not complete yet' do
      let(:complete) { false }

      after { expect(batch).to have_received(:update_state) }
      after { expect(worker).to have_received(:on_child_complete) }
      after { expect(parent_batch).not_to have_received(:on_child_complete) }
      it { is_expected.to be_falsey }
    end

    context 'with no parent batch' do
      let(:parent_batch) { nil }

      after { expect(batch).to have_received(:update_state) }
      after { expect(worker).to have_received(:on_child_complete) }
      it { is_expected.to be_falsey }
    end
  end

  describe '#on_batch_node_complete' do
    subject { batch.on_batch_node_complete(child_batch) }

    let(:parent_batch) { instance_double(described_class.to_s) }

    before do
      allow(batch).to receive(:parent_batch).and_return(parent_batch)
      allow(worker).to receive(:on_batch_node_complete).with(child_batch.worker)

      if parent_batch
        allow(parent_batch).to(
          receive(:on_batch_node_complete).with(child_batch)
        ).and_return(true)
      end
    end

    context 'with parent batch' do
      after { expect(worker).to have_received(:on_batch_node_complete) }
      after { expect(parent_batch).to have_received(:on_batch_node_complete) }
      it { is_expected.to be_truthy }
    end

    context 'with no parent batch' do
      let(:parent_batch) { nil }

      after { expect(worker).to have_received(:on_batch_node_complete) }
      it { is_expected.to be_falsey }
    end
  end

  describe '#progress' do
    subject { batch.progress }

    before do
      child_batch.jobs.push(worker.new_instance)
      child_batch.jobs.push(worker.new_instance)
      child_batch.jobs.push(worker.new_instance)
      child_batch.save
      child_batch.update_state(child_batch.jobs[0].job_id, 'completed')
      child_batch.update_state(child_batch.jobs[1].job_id, 'processing')

      batch.jobs.push(child_worker)
      batch.save
    end

    it { is_expected.to be_a(Cloudtasker::Batch::BatchProgress) }
    it { is_expected.to have_attributes(total: 4, completed: 1, scheduled: 2, processing: 1) }
  end

  describe '#complete' do
    subject { batch.complete }

    let(:complete) { false }
    let(:parent_batch) { instance_double(described_class.to_s) }

    before do
      allow(batch).to receive(:complete?).and_return(complete)
      allow(batch).to receive(:parent_batch).and_return(parent_batch)
      allow(batch).to receive(:on_child_complete)
      allow(worker).to receive(:on_batch_complete)

      if parent_batch
        allow(parent_batch).to(receive(:on_child_complete).with(batch)).and_return(true)
        allow(parent_batch).to(receive(:on_batch_node_complete).with(batch)).and_return(true)
      end
    end

    context 'with job reenqueued' do
      before { worker.job_reenqueued = true }
      after { expect(worker).not_to have_received(:on_batch_complete) }
      after { expect(parent_batch).not_to have_received(:on_child_complete) }
      after { expect(parent_batch).not_to have_received(:on_batch_node_complete) }
      it { is_expected.to be_truthy }
    end

    context 'with child jobs' do
      before { batch.jobs.push(worker.new_instance) }
      after { expect(worker).not_to have_received(:on_batch_complete) }
      after { expect(parent_batch).not_to have_received(:on_child_complete) }
      after { expect(parent_batch).not_to have_received(:on_batch_node_complete) }
      it { is_expected.to be_truthy }
    end

    context 'with batch incomplete' do
      after { expect(worker).not_to have_received(:on_batch_complete) }
      after { expect(parent_batch).not_to have_received(:on_child_complete) }
      after { expect(parent_batch).to have_received(:on_batch_node_complete) }
      it { is_expected.to be_truthy }
    end

    context 'with batch complete' do
      let(:complete) { true }

      after { expect(worker).to have_received(:on_batch_complete) }
      after { expect(parent_batch).to have_received(:on_child_complete) }
      after { expect(parent_batch).to have_received(:on_batch_node_complete) }
      it { is_expected.to be_truthy }
    end

    context 'with batch complete no parent batch' do
      let(:complete) { true }

      after { expect(worker).to have_received(:on_batch_complete) }
      it { is_expected.to be_truthy }
    end
  end

  describe '#execute' do
    subject { batch.execute }

    let(:parent_batch) { instance_double(described_class.to_s) }

    before { allow(batch).to receive(:parent_batch).and_return(parent_batch) }
    before { parent_batch && allow(parent_batch).to(receive(:update_state).with(batch.batch_id, :processing)) }
    before { allow(batch).to receive(:setup) }
    before { allow(batch).to receive(:complete) }

    after { expect(batch).to have_received(:setup) }
    after { expect(batch).to have_received(:complete) }

    context 'with parent_batch' do
      after { expect(parent_batch).to have_received(:update_state) }
      it { expect { |b| batch.execute(&b) }.to yield_control }
    end

    context 'with no parent batch' do
      let(:parent_batch) { nil }

      it { expect { |b| batch.execute(&b) }.to yield_control }
    end
  end
end
