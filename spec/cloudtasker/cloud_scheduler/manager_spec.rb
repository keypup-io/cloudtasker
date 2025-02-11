# frozen_string_literal: true

require 'google/cloud/scheduler/v1'

RSpec.describe Cloudtasker::CloudScheduler::Manager do
  let(:manager) { described_class.new(jobs) }
  let(:parent_path) { '/path/to/parent' }
  let(:queue_prefix) { Cloudtasker.config.gcp_queue_prefix }
  let(:client) do
    instance_double(
      Google::Cloud::Scheduler::V1::CloudScheduler::Client,
      location_path: parent_path,
      create_job: Google::Cloud::Scheduler::V1::Job.new,
      update_job: Google::Cloud::Scheduler::V1::Job.new,
      delete_job: Google::Protobuf::Empty.new
    )
  end
  let(:jobs) do
    [
      Cloudtasker::CloudScheduler::Job.new(
        Cloudtasker::CloudScheduler::Schedule.new(
          id: 'test',
          cron: '* * * * *',
          worker: 'TestWorker',
          args: 'foo',
          queue: 'default',
          time_zone: 'America/New_York'
        )
      )
    ]
  end

  before do
    allow(Google::Cloud::Scheduler).to receive(:cloud_scheduler).and_return(client)
  end

  describe '.synchronize!' do
    subject(:synchronize!) { described_class.synchronize!(file) }

    let(:file) { 'path/to/file' }
    let(:config) { { 'test' => { 'worker' => 'TestWorker' } } }
    let(:jobs) { [instance_double(Cloudtasker::CloudScheduler::Job, create!: nil, update!: nil)] }
    let(:manager) { instance_double(described_class, synchronize!: nil) }

    before do
      allow(YAML).to receive(:load_file).with(file).and_return(config)
      allow(Cloudtasker::CloudScheduler::Job).to receive(:load_from_hash!).with(config).and_return(jobs)
      allow(described_class).to receive(:new).with(jobs).and_return(manager)
    end

    after { expect(manager).to have_received(:synchronize!) }

    it { is_expected.to be_nil }
  end

  describe '#synchronize!' do
    subject(:synchronize!) { manager.synchronize! }

    let(:new_jobs) { [instance_double(Cloudtasker::CloudScheduler::Job, create!: nil)] }
    let(:stale_jobs) { [instance_double(Cloudtasker::CloudScheduler::Job, update!: nil)] }
    let(:deleted_jobs) { ['path/to/deleted/job'] }

    before do
      allow(manager).to receive(:new_jobs).and_return(new_jobs)
      allow(manager).to receive(:stale_jobs).and_return(stale_jobs)
      allow(manager).to receive(:deleted_jobs).and_return(deleted_jobs)
    end

    after do
      expect(new_jobs.first).to have_received(:create!)
      expect(stale_jobs.first).to have_received(:update!)
      expect(client).to have_received(:delete_job).with(name: deleted_jobs.first)
    end

    it { is_expected.to be_nil }
  end
end
