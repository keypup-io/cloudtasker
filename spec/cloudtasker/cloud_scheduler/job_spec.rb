# frozen_string_literal: true

require 'google/cloud/scheduler/v1'

RSpec.describe Cloudtasker::CloudScheduler::Job do
  let(:job) { described_class.new(scheduler) }
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
  let(:scheduler) do
    Cloudtasker::CloudScheduler::Schedule.new(
      id: 'test',
      cron: '* * * * *',
      worker: 'TestWorker',
      args: 'foo',
      queue: 'default',
      time_zone: 'America/New_York'
    )
  end

  before do
    allow(Google::Cloud::Scheduler).to receive(:cloud_scheduler).and_return(client)
  end

  describe '.load_from_hash!' do
    subject(:jobs) { described_class.load_from_hash!(hash) }

    let(:hash) do
      {
        'test' => {
          'worker' => 'DummyWorker',
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

    context 'with a valid schedule' do
      it { is_expected.to be_a(Array) }
      it { expect(jobs.size).to eq(1) }
      it { expect(jobs.first).to be_a(described_class) }
    end
  end

  describe '.new' do
    it { expect(job.schedule).to eq(scheduler) }
  end

  describe '#prefix' do
    subject(:parent) { job.prefix }

    it { is_expected.to eq("#{parent_path}/jobs/#{queue_prefix}--") }
  end

  describe '#remote_name' do
    subject(:name) { job.remote_name }

    it { is_expected.to eq("#{parent_path}/jobs/#{queue_prefix}--#{scheduler.id}") }
  end

  describe '#name' do
    subject(:name) { job.name }

    it { is_expected.to eq(scheduler.id) }
  end

  describe '#create!' do
    subject(:create!) { job.create! }

    after { expect(client).to have_received(:create_job) }

    it { is_expected.to be_a(Google::Cloud::Scheduler::V1::Job) }
  end

  describe '#update!' do
    subject(:update!) { job.update! }

    after { expect(client).to have_received(:update_job) }

    it { is_expected.to be_a(Google::Cloud::Scheduler::V1::Job) }
  end

  describe '#delete!' do
    subject(:delete!) { job.delete! }

    after { expect(client).to have_received(:delete_job) }

    it { is_expected.to be_a(Google::Protobuf::Empty) }
  end

  describe '#payload' do
    subject(:payload) { job.payload }

    before { allow(Cloudtasker::Authenticator).to receive(:bearer_token).and_return('token') }

    it { expect(payload[:name]).to eq(job.remote_name) }
    it { expect(payload[:schedule]).to eq(scheduler.cron) }
    it { expect(payload[:time_zone]).to eq(scheduler.time_zone) }
    it { expect(payload[:http_target][:http_method]).to eq('POST') }
    it { expect(payload[:http_target][:uri]).to eq(Cloudtasker.config.processor_url) }
    it { expect(payload[:http_target][:oidc_token]).to eq(Cloudtasker.config.oidc) }
    it { expect(payload[:http_target][:body]).to eq(scheduler.job_payload.to_json) }

    it {
      expect(payload[:http_target][:headers]).to eq({
                                                      Cloudtasker::Config::CONTENT_TYPE_HEADER => 'application/json',
                                                      Cloudtasker::Config::CT_AUTHORIZATION_HEADER => 'token'
                                                    })
    }
  end
end
