# frozen_string_literal: true

RSpec.describe Cloudtasker::CloudScheduler::Schedule do
  describe '.load_from_hash!' do
    subject(:schedules) { described_class.load_from_hash!(hash) }

    let(:hash) do
      {
        'test' => {
          'worker' => 'TestWorker',
          'cron' => '* * * * *',
          'args' => { 'foo' => 'bar' },
          'queue' => 'default',
          'time_zone' => 'America/New_York',
          'active_job' => true
        }
      }
    end

    context 'with an empty hash' do
      let(:hash) { {} }

      it { is_expected.to eq([]) }
    end

    context 'with an invalid schedule' do
      let(:hash) { { 'test' => { 'worker' => 'TestWorker' } } }

      it 'raises an error' do
        expect { schedules }.to raise_error(Cloudtasker::CloudScheduler::InvalidScheduleError)
      end
    end

    context 'with a valid schedule' do
      it { is_expected.to be_a(Array) }
      it { expect(schedules.size).to eq(1) }
      it { expect(schedules.first).to be_a(described_class) }
    end
  end

  describe '.new' do
    subject(:schedule) do
      described_class.new(
        id: id,
        cron: cron,
        worker: worker,
        args: args,
        queue: queue,
        time_zone: time_zone
      )
    end

    let(:id) { 'test' }
    let(:cron) { '* * * * *' }
    let(:worker) { 'TestWorker' }
    let(:args) { { foo: 'bar' } }
    let(:queue) { 'default' }
    let(:time_zone) { 'America/New_York' }

    it { expect(schedule.id).to eq(id) }
    it { expect(schedule.cron).to eq(cron) }
    it { expect(schedule.worker).to eq(worker) }
    it { expect(schedule.args).to eq(args) }
    it { expect(schedule.queue).to eq(queue) }
    it { expect(schedule.time_zone).to eq(time_zone) }
  end

  describe '#valid?' do
    subject { described_class.new(id: id, cron: cron, worker: worker).valid? }

    let(:id) { 'test' }
    let(:cron) { '* * * * *' }
    let(:worker) { 'TestWorker' }

    context 'with blank id' do
      let(:id) { '' }

      it { is_expected.not_to be_truthy }
    end

    context 'with an invalid cron' do
      let(:cron) { 'invalid' }

      it { is_expected.not_to be_truthy }
    end

    context 'with a blank worker' do
      let(:worker) { '' }

      it { is_expected.not_to be_truthy }
    end

    context 'with a valid id, cron and worker' do
      it { is_expected.to be_truthy }
    end
  end

  describe '#cron_schedule' do
    subject { described_class.new(id: 'test', cron: cron, worker: 'TestWorker').cron_schedule }

    let(:cron) { '* * * * *' }

    it { is_expected.to be_a(Fugit::Cron) }
  end

  describe '#active_job?' do
    subject do
      described_class.new(id: 'test', cron: '* * * * *', worker: 'TestWorker', active_job: active_job).active_job?
    end

    let(:active_job) { true }

    context 'with active_job set to true' do
      it { is_expected.to be_truthy }
    end

    context 'with active_job set to false' do
      let(:active_job) { false }

      it { is_expected.not_to be_truthy }
    end
  end

  describe '#job_payload' do
    subject(:payload) do
      described_class.new(
        id: 'test',
        cron: '* * * * *',
        worker: worker,
        args: args,
        queue: queue,
        active_job: active_job,
        time_zone: time_zone
      ).job_payload
    end

    let(:worker) { 'TestWorker' }
    let(:args) { { 'foo' => 'bar' } }
    let(:queue) { 'default' }
    let(:active_job) { false }
    let(:time_zone) { 'America/New_York' }

    before do
      allow(TestActiveJob).to receive(:new).and_return(TestActiveJob.new)
      allow_any_instance_of(TestActiveJob).to receive(:queue_name=).and_return(queue)
      allow_any_instance_of(TestActiveJob).to receive(:queue_name).and_return(queue)
      allow_any_instance_of(TestActiveJob).to receive(:timezone=).and_return(time_zone)
      allow_any_instance_of(TestActiveJob).to receive(:timezone).and_return(time_zone)
      allow_any_instance_of(TestActiveJob).to receive(:job_id).and_return('1234')
      allow_any_instance_of(TestActiveJob).to receive(:serialize).and_return('{}')
    end

    context 'with a regular worker' do
      it { is_expected.to be_a(Hash) }
      it { expect(payload['worker']).to eq(worker) }
      it { expect(payload['job_queue']).to eq(queue) }
      it { expect(payload['job_args']).to eq(args) }
    end

    context 'with an ActiveJob worker' do
      let(:worker) { 'TestActiveJob' }
      let(:active_job) { true }

      it { is_expected.to be_a(Hash) }
      it { expect(payload['worker']).to eq('ActiveJob::QueueAdapters::CloudtaskerAdapter::JobWrapper') }
      it { expect(payload['job_queue']).to eq(queue) }
      it { expect(payload['job_args']).to eq(['{}']) }
      it { expect(payload['job_id']).to eq('1234') }
      it { expect(payload['job_meta']).to eq({}) }
    end
  end
end
