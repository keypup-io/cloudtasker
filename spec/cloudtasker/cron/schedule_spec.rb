# frozen_string_literal: true

require 'cloudtasker/cron/middleware'

RSpec.describe Cloudtasker::Cron::Schedule do
  let(:redis) { described_class.redis }
  let(:id) { 'SomeScheduleId' }
  let(:cron) { '0 0 * * *' }
  let(:worker_klass) { TestWorker }
  let(:worker_args) { ['foo', 1] }
  let(:worker_queue) { 'critical' }
  let(:schedule) do
    described_class.new(
      id: id,
      cron: cron,
      worker: worker_klass.to_s,
      args: worker_args,
      queue: worker_queue
    )
  end

  describe '.redis' do
    subject { described_class.redis }

    it { is_expected.to be_a(Cloudtasker::RedisClient) }
  end

  describe '.key' do
    subject { described_class.key(val) }

    context 'with value' do
      let(:val) { :some_key }

      it { is_expected.to eq([described_class.to_s.underscore, val.to_s].join('/')) }
    end

    context 'with nil' do
      let(:val) { nil }

      it { is_expected.to eq(described_class.to_s.underscore) }
    end
  end

  describe '.all' do
    subject { described_class.all&.sort_by(&:id) }

    let!(:schedules) do
      3.times.map do |n|
        described_class
          .new(id: "schedule/#{n}", cron: cron, worker: worker_klass.to_s)
          .tap { |e| e.save(update_task: false) }
      end.sort_by(&:id)
    end

    context 'with schedule set available' do
      after { expect(redis.smembers(described_class.key).sort).to eq(schedules.map(&:id)) }
      it { is_expected.to eq(schedules) }
    end

    context 'without schedule set available' do
      before { redis.del(described_class.key) }
      after { expect(redis.smembers(described_class.key).sort).to eq(schedules.map(&:id)) }
      it { is_expected.to eq(schedules) }
    end
  end

  describe '.load_from_hash!' do
    subject { described_class.load_from_hash!(hash) }

    let(:schedule) { described_class.new(id: id, cron: cron, worker: worker_klass.to_s) }
    let(:existing) { described_class.new(id: 'ToDelete', cron: cron, worker: worker_klass.to_s) }
    let(:hash) do
      {
        id.to_sym => { cron: cron, worker: worker_klass.to_s }
      }
    end

    before do
      allow(described_class).to receive(:all).and_return([schedule, existing])
      allow(described_class).to(
        receive(:create).with(id: id, cron: cron, worker: worker_klass.to_s).and_return(schedule)
      )
      allow(described_class).to receive(:delete).with(existing.id)
    end
    after { expect(described_class).to have_received(:create) }
    after { expect(described_class).to have_received(:delete) }
    it { is_expected.to be_truthy }
  end

  describe '.create' do
    subject { described_class.create(id: id, cron: cron, worker: worker_klass.to_s) }

    let(:record) { instance_double(described_class.to_s) }
    let(:existing_record) { instance_double(described_class.to_s, to_h: { job_id: job_id }) }
    let(:job_id) { '111' }
    let(:expected_attrs) { { id: id, cron: cron, worker: worker_klass.to_s } }

    before { allow(described_class).to receive(:new).and_return(record) }
    before { allow(record).to receive(:save) }

    context 'with existing schedule' do
      before { allow(described_class).to receive(:find).with(id).and_return(existing_record) }
      after { expect(described_class).to have_received(:new).with(expected_attrs.merge(job_id: job_id)) }
      after { expect(record).to have_received(:save) }
      it { is_expected.to eq(record) }
    end

    context 'with no existing schedule' do
      before { allow(described_class).to receive(:find).with(id).and_return(nil) }
      after { expect(described_class).to have_received(:new).with(expected_attrs) }
      after { expect(record).to have_received(:save) }
      it { is_expected.to eq(record) }
    end
  end

  describe '.find' do
    subject { described_class.find(id) }

    before { schedule.save(update_task: false) }
    it { is_expected.to eq(schedule) }
  end

  describe '.delete' do
    subject { described_class.find(id) }

    let(:task_id) { nil }

    before { allow(Cloudtasker::CloudTask).to receive(:delete).with(task_id) }
    before { schedule.task_id = task_id }
    before { schedule.save(update_task: false) }

    context 'with task id' do
      let(:task_id) { '222' }

      before { described_class.delete(id) }
      after { expect(redis.smembers(described_class.key)).to eq([]) }
      after { expect(Cloudtasker::CloudTask).to have_received(:delete) }
      it { is_expected.to be_nil }
    end

    context 'without task id' do
      before { described_class.delete(id) }
      it { is_expected.to be_nil }
    end

    context 'with non-existing id' do
      it { expect { described_class.delete(id + 'a') }.not_to raise_error }
    end
  end

  describe '.new' do
    subject { described_class.new(**attrs) }

    let(:attrs) do
      {
        id: id,
        cron: cron,
        worker: worker_klass.to_s,
        args: worker_args,
        queue: worker_queue,
        task_id: '1',
        job_id: '2'
      }
    end

    it { is_expected.to have_attributes(attrs) }
  end

  describe '#redis' do
    subject { schedule.redis }

    it { is_expected.to be_a(Cloudtasker::RedisClient) }
  end

  describe '#gid' do
    subject { schedule.gid }

    it { is_expected.to eq(described_class.key(schedule.id)) }
  end

  describe '#valid?' do
    subject { schedule }

    context 'with valid cron' do
      it { is_expected.to be_valid }
    end

    context 'with invalid cron' do
      let(:cron) { '----' }

      it { is_expected.not_to be_valid }
    end
  end

  describe '#==' do
    subject { schedule }

    context 'with same id' do
      it { is_expected.to eq(described_class.new(id: id, cron: cron, worker: worker_klass.to_s)) }
    end

    context 'with different id' do
      it { is_expected.not_to eq(described_class.new(id: id + 'a', cron: cron, worker: worker_klass.to_s)) }
    end

    context 'with different object' do
      it { is_expected.not_to eq('foo') }
    end
  end

  describe '#config_changed?' do
    subject { schedule }

    context 'with non-persisted schedule' do
      it { is_expected.to be_config_changed }
    end

    context 'with persisted and changed schedule' do
      before { schedule.save(update_task: false) }
      before { schedule.cron = cron.gsub('0', '1') }
      it { is_expected.to be_config_changed }
    end

    context 'with persisted and unmodified schedule' do
      before { schedule.save(update_task: false) }
      it { is_expected.not_to be_config_changed }
    end

    context 'with changes on non-config attributes' do
      before { schedule.save(update_task: false) }
      before { schedule.task_id = '111' }
      it { is_expected.not_to be_config_changed }
    end
  end

  describe '#changed?' do
    subject { schedule }

    context 'with non-persisted schedule' do
      it { is_expected.to be_changed }
    end

    context 'with persisted and changed schedule' do
      before { schedule.save(update_task: false) }
      before { schedule.task_id = '222' }
      it { is_expected.to be_changed }
    end

    context 'with persisted and unmodified schedule' do
      before { schedule.save(update_task: false) }
      it { is_expected.not_to be_changed }
    end
  end

  describe '#to_config' do
    subject { schedule.to_config }

    let(:expected_config) do
      {
        id: id,
        cron: cron,
        worker: worker_klass.to_s,
        args: worker_args,
        queue: worker_queue
      }
    end

    it { is_expected.to eq(expected_config) }
  end

  describe '#to_h' do
    subject { schedule.to_h }

    let(:task_id) { '111' }
    let(:job_id) { '222' }
    let(:expected_hash) do
      {
        id: id,
        cron: cron,
        worker: worker_klass.to_s,
        args: worker_args,
        queue: worker_queue,
        task_id: task_id,
        job_id: job_id
      }
    end

    before { schedule.assign_attributes(task_id: task_id, job_id: job_id) }
    it { is_expected.to eq(expected_hash) }
  end

  describe '#worker_instance' do
    subject { schedule.worker_instance }

    let(:attrs) { { worker_name: worker_klass.to_s, job_args: worker_args, job_queue: worker_queue } }

    it { is_expected.to be_a(Cloudtasker::WorkerWrapper) }
    it { is_expected.to have_attributes(attrs) }
  end

  describe '#cron_schedule' do
    subject { schedule.cron_schedule }

    it { is_expected.to eq(Fugit::Cron.parse(cron)) }
  end

  describe '#next_time' do
    subject { schedule.next_time(now) }

    let(:now) { Time.now }

    it { is_expected.to eq(schedule.cron_schedule.next_time(now)) }
  end

  describe '#assign_attributes' do
    subject { schedule }

    let(:attrs) { { task_id: '111', job_id: '222' } }

    before { schedule.assign_attributes(attrs) }
    it { is_expected.to have_attributes(attrs) }
  end

  describe '#update' do
    subject { schedule.update(attrs) }

    let(:attrs) { { task_id: '111', job_id: '222' } }

    before { allow(schedule).to receive(:save).and_return(true) }
    after { expect(schedule).to have_received(:save) }
    after { expect(schedule).to have_attributes(attrs) }
    it { is_expected.to be_truthy }
  end

  describe '#save' do
    subject { schedule.save }

    let(:job) { instance_double('Cloudtasker::Cron::Job') }
    let(:existing_task) { nil }
    let(:task_id) { nil }
    let(:wrapper) { instance_double('Cloudtasker::WorkerWrapper') }

    before do
      schedule.task_id = task_id
      allow(schedule).to receive(:worker_instance).and_return(wrapper)
      allow(Cloudtasker::Cron::Job).to receive(:new).with(wrapper).and_return(job)
      allow(job).to receive(:set).with(schedule_id: id).and_return(job)
      allow(job).to receive(:schedule!).and_return(true)
      allow(Cloudtasker::CloudTask).to receive(:delete).with(be_a(String))
      allow(Cloudtasker::CloudTask).to receive(:find).with(be_a(String)).and_return(existing_task)
    end

    context 'with invalid schedule' do
      before { allow(schedule).to receive(:valid?).and_return(false) }
      after { expect(described_class.find(id)).to be_nil }
      after { expect(redis.smembers(described_class.key)).to be_empty }
      after { expect(job).not_to have_received(:schedule!) }
      it { is_expected.to be_falsey }
    end

    context 'with config changed' do
      before { allow(schedule).to receive(:config_changed?).and_return(true) }
      after { expect(described_class.find(id)).to eq(schedule) }
      after { expect(redis.smembers(described_class.key)).to eq([schedule.id]) }
      after { expect(job).to have_received(:schedule!) }
      it { is_expected.to be_truthy }
    end

    context 'with config changed and task id' do
      let(:task_id) { '222' }

      before { allow(schedule).to receive(:config_changed?).and_return(true) }
      after { expect(described_class.find(id)).to eq(schedule) }
      after { expect(redis.smembers(described_class.key)).to eq([schedule.id]) }
      after { expect(job).to have_received(:schedule!) }
      after { expect(Cloudtasker::CloudTask).to have_received(:delete).with(task_id) }
      it { is_expected.to be_truthy }
    end

    context 'with non-config attributes changed' do
      let(:task_id) { '222' }
      let(:existing_task) { instance_double('Cloudtasker::CloudTask') }

      before { allow(schedule).to receive(:config_changed?).and_return(false) }
      after { expect(described_class.find(id)).to eq(schedule) }
      after { expect(redis.smembers(described_class.key)).to eq([schedule.id]) }
      after { expect(job).not_to have_received(:schedule!) }
      it { is_expected.to be_truthy }
    end

    context 'with no change but cloud task absent in backend' do
      let(:task_id) { '222' }
      let(:existing_task) { nil }

      before { allow(schedule).to receive(:config_changed?).and_return(false) }
      after { expect(described_class.find(id)).to eq(schedule) }
      after { expect(redis.smembers(described_class.key)).to eq([schedule.id]) }
      after { expect(job).to have_received(:schedule!) }
      after { expect(Cloudtasker::CloudTask).to have_received(:delete).with(task_id) }
      it { is_expected.to be_truthy }
    end
  end
end
