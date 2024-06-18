# frozen_string_literal: true

require 'cloudtasker/cron/middleware'

RSpec.describe Cloudtasker::Cron::Job do
  let(:schedule_id) { 'SomeTask' }
  let(:cron) { '0 0 * * *' }
  let(:cron_schedule) { Cloudtasker::Cron::Schedule.new(id: schedule_id, cron: cron, worker: worker.class.to_s) }
  let(:worker) { TestWorker.new }
  let(:job) { described_class.new(worker) }

  describe '.new' do
    subject { job }

    it { is_expected.to have_attributes(worker: worker) }
  end

  describe '#key' do
    subject { job.key(val) }

    context 'with value' do
      let(:val) { :some_key }

      it { is_expected.to eq([described_class.to_s.underscore, val.to_s].join('/')) }
    end

    context 'with nil' do
      let(:val) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe '#set' do
    subject(:job_set) { job.set(schedule_id: schedule_id) }

    before { job_set }
    it { expect(worker.job_meta.get(job.key(:schedule_id))).to eq(schedule_id) }
    it { is_expected.to eq(job) }
  end

  describe '#job_id' do
    subject { job.job_id }

    it { is_expected.to eq(worker.job_id) }
  end

  describe '#job_gid' do
    subject { job.job_gid }

    it { is_expected.to eq(job.key(job.job_id)) }
  end

  describe 'schedule_id' do
    subject { job.schedule_id }

    context 'with cron instance job' do
      before { job.set(schedule_id: schedule_id) }
      it { is_expected.to eq(schedule_id) }
    end

    context 'with regular job' do
      it { is_expected.to be_nil }
    end
  end

  describe '#cron_job?' do
    subject { job }

    context 'with cron schedule' do
      before { allow(job).to receive(:cron_schedule).and_return(cron_schedule) }
      it { is_expected.to be_cron_job }
    end

    context 'with no cron schedule' do
      it { is_expected.not_to be_cron_job }
    end
  end

  describe '#retry_instance?' do
    subject { job }

    context 'with cron metadata and processing flag' do
      before { allow(job).to receive(:cron_schedule).and_return(cron_schedule) }
      before { job.flag(:processing) }
      it { is_expected.to be_retry_instance }
    end

    context 'with cron metadata and no processing flag' do
      before { allow(job).to receive(:cron_schedule).and_return(cron_schedule) }
      it { is_expected.not_to be_retry_instance }
    end

    context 'with no cron metadata' do
      it { is_expected.not_to be_retry_instance }
    end
  end

  describe '#state' do
    subject { job.state }

    context 'with stored state' do
      before { job.flag(:processing) }
      it { is_expected.to eq(:processing) }
    end

    context 'with no stored state' do
      it { is_expected.to be_nil }
    end
  end

  describe '#redis' do
    subject { job.redis }

    it { is_expected.to be_a(Cloudtasker::RedisClient) }
  end

  describe '#cron_schedule' do
    subject { job.cron_schedule }

    context 'with no schedule_id' do
      it { is_expected.to be_nil }
    end

    context 'with a schedule_id' do
      before { allow(Cloudtasker::Cron::Schedule).to receive(:find).with(schedule_id).and_return(cron_schedule) }
      before { job.set(schedule_id: schedule_id) }
      it { is_expected.to eq(cron_schedule) }
    end
  end

  describe '#current_time' do
    subject { job.current_time }

    before { job.set(schedule_id: schedule_id) }

    context 'with time_at in meta' do
      let(:time_at) { (Time.now - 3600).iso8601 }

      before { worker.job_meta.set(job.key(:time_at), time_at) }
      it { is_expected.to eq(Time.parse(time_at)) }
    end

    context 'with no time_at' do
      around { |e| Timecop.freeze { e.run } }
      it { is_expected.to eq(Time.now) }
    end

    context 'with no time_at and Time.current' do
      let(:time_current) { instance_double(Time) }

      before { allow(Time).to receive(:current).and_return(time_current) }
      around { |e| Timecop.freeze { e.run } }
      it { is_expected.to eq(time_current) }
    end
  end

  describe '#next_time' do
    subject { job.next_time }

    let(:current_time) { Time.now - (3600 * 24 * 30) }

    before do
      allow(job).to receive_messages(cron_schedule: cron_schedule, current_time: current_time)
    end

    it { is_expected.to eq(cron_schedule.next_time(current_time)) }
  end

  describe '#expected_instance?' do
    subject { job }

    before { allow(job).to receive(:cron_schedule).and_return(cron_schedule) }

    context 'with expected cron job' do
      before { cron_schedule.job_id = job.job_id }
      it { is_expected.to be_expected_instance }
    end

    context 'with retry instance' do
      before { allow(job).to receive(:retry_instance?).and_return(true) }
      it { is_expected.to be_expected_instance }
    end

    context 'with unexpected cron job' do
      it { is_expected.not_to be_expected_instance }
    end
  end

  describe '#flag' do
    subject { job.redis.get(job.job_gid) }

    context 'with :done state' do
      before { job.flag(:processing) }
      before { job.flag(:done) }
      it { is_expected.to be_nil }
    end

    context 'with other state' do
      before { job.flag(:processing) }
      it { is_expected.to eq('processing') }
    end
  end

  describe '#schedule!' do
    subject { job.schedule! }

    let(:next_worker) { TestWorker.new }
    let(:task_id) { 'some-task-id' }
    let(:resp) { instance_double(Cloudtasker::CloudTask, id: task_id) }

    before do
      allow(worker).to receive(:new_instance).and_return(next_worker)
      allow(job).to receive(:cron_schedule).and_return(cron_schedule)
      allow(cron_schedule).to receive(:update).with(task_id: task_id, job_id: next_worker.job_id).and_return(true)
    end

    context 'with no cron_schedule' do
      let(:cron_schedule) { nil }

      before { expect(next_worker).not_to receive(:schedule) }
      it { is_expected.to be_falsey }
    end

    context 'with cron_schedule' do
      before { expect(next_worker).to receive(:schedule).with(time_at: job.next_time).and_return(resp) }
      after { expect(next_worker.job_meta.get(job.key(:time_at))).to eq(job.next_time.iso8601) }
      it { is_expected.to be_truthy }
    end
  end

  describe '#execute' do
    before { allow(job).to receive(:schedule!) }

    context 'with regular job' do
      it { expect { |b| job.execute(&b) }.to yield_control }
    end

    context 'with unexpected cron job instance' do
      before { allow(job).to receive(:cron_schedule).and_return(cron_schedule) }
      before { allow(job).to receive(:expected_instance?).and_return(false) }
      it { expect { |b| job.execute(&b) }.not_to yield_control }
    end

    context 'with expected cron job instance' do
      before { allow(job).to receive(:cron_schedule).and_return(cron_schedule) }
      before { allow(job).to receive(:expected_instance?).and_return(true) }
      after { expect(job).to have_received(:schedule!) }
      it { expect { |b| job.execute(&b) }.to yield_control }
    end

    context 'with cron instance runtime error' do
      before { allow(job).to receive(:cron_schedule).and_return(cron_schedule) }
      before { allow(job).to receive(:expected_instance?).and_return(true) }
      after { expect(job.state).to eq(:processing) }
      it { expect { job.execute { raise(StandardError) } }.to raise_error(StandardError) }
    end
  end
end
