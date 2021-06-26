# frozen_string_literal: true

require 'cloudtasker/backend/google_cloud_task'

RSpec.describe Cloudtasker::Backend::GoogleCloudTask do
  let(:relative_queue) { 'critical' }
  let(:task_name) do
    [
      'projects',
      config.gcp_project_id,
      'locations',
      config.gcp_location_id,
      'queues',
      "#{config.gcp_queue_prefix}-#{relative_queue}",
      'tasks',
      '111-222'
    ].join('/')
  end
  let(:job_payload) do
    {
      http_request: {
        http_method: 'POST',
        url: 'http://localhost:300/run',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer 123'
        },
        body: { foo: 'bar' }.to_json
      },
      schedule_time: 2,
      queue: relative_queue
    }
  end
  let(:config) { Cloudtasker.config }
  let(:client) { instance_double('Google::Cloud::Tasks::V2beta3::Task') }

  describe '.setup_queue' do
    subject { described_class.setup_queue(**opts) }

    let(:opts) { { name: relative_queue, concurrency: 20, retries: 100 } }
    let(:queue) { instance_double('Google::Cloud::Tasks::V2beta3::Queue') }
    let(:base_path) { 'foo/bar' }
    let(:queue_path) { 'foo/bar/baz' }
    let(:expected_payload) do
      [
        base_path,
        {
          name: queue_path,
          retry_config: { max_attempts: opts[:retries] },
          rate_limits: { max_concurrent_dispatches: opts[:concurrency] }
        }
      ]
    end

    before do
      allow(described_class).to receive(:client).and_return(client)
      allow(client).to receive(:location_path).with(config.gcp_project_id, config.gcp_location_id).and_return(base_path)
      allow(described_class).to receive(:queue_path).with(relative_queue).and_return(queue_path)
      allow(client).to receive(:create_queue).with(*expected_payload).and_return(queue)

      allow(client).to receive(:get_queue)
        .with(queue_path)
        .and_raise(Google::Gax::RetryError.new('msg'))
    end

    context 'with existing queue' do
      before { allow(client).to receive(:get_queue).with(queue_path).and_return(queue) }
      after { expect(client).not_to have_received(:create_queue) }
      it { is_expected.to eq(queue) }
    end

    context 'with no existing queue' do
      after { expect(client).to have_received(:create_queue) }
      it { is_expected.to eq(queue) }
    end

    context 'with empty opts' do
      let(:opts) { {} }
      let(:relative_queue) { Cloudtasker::Config::DEFAULT_JOB_QUEUE }
      let(:expected_payload) do
        [
          base_path,
          {
            name: queue_path,
            retry_config: { max_attempts: Cloudtasker::Config::DEFAULT_QUEUE_RETRIES },
            rate_limits: { max_concurrent_dispatches: Cloudtasker::Config::DEFAULT_QUEUE_CONCURRENCY }
          }
        ]
      end

      after { expect(client).to have_received(:create_queue) }
      it { is_expected.to eq(queue) }
    end
  end

  describe '.client' do
    subject { described_class.client }

    before { allow(Google::Cloud::Tasks).to receive(:new).with(version: :v2beta3).and_return(client) }

    it { is_expected.to eq(client) }
  end

  describe '.config' do
    subject { described_class.config }

    it { is_expected.to eq(config) }
  end

  describe '.queue_path' do
    subject { described_class.queue_path(relative_queue) }

    let(:queue) { 'some-queue' }
    let(:expected_args) do
      [
        config.gcp_project_id,
        config.gcp_location_id,
        [config.gcp_queue_prefix, relative_queue].join('-')
      ]
    end

    before { allow(described_class).to receive(:client).and_return(client) }
    before { allow(client).to receive(:queue_path).with(*expected_args).and_return(queue) }
    it { is_expected.to eq(queue) }
  end

  describe '.format_schedule_time' do
    subject { described_class.format_schedule_time(timestamp) }

    context 'with nil' do
      let(:timestamp) { nil }

      it { is_expected.to be_nil }
    end

    context 'with timestamp' do
      let(:timestamp) { Time.now.to_i }
      let(:expected) { Google::Protobuf::Timestamp.new.tap { |e| e.seconds = timestamp } }

      it { is_expected.to eq(expected) }
    end
  end

  describe '.format_task_payload' do
    subject { described_class.format_task_payload(job_payload) }

    let(:expected_payload) do
      payload = JSON.parse(job_payload.to_json, symbolize_names: true)
      payload[:schedule_time] = described_class.format_schedule_time(job_payload[:schedule_time])
      payload[:http_request][:headers]['Content-Type'] = 'text/json'
      payload[:http_request][:headers]['Content-Transfer-Encoding'] = 'Base64'
      payload[:http_request][:body] = Base64.encode64(job_payload[:http_request][:body])
      payload
    end

    it { is_expected.to eq(expected_payload) }
  end

  describe '.find' do
    subject { described_class.find(id) }

    let(:id) { '123' }
    let(:resp) { instance_double('Google::Cloud::Tasks::V2beta3::Task') }
    let(:task) { instance_double(described_class.to_s) }

    before { allow(described_class).to receive(:client).and_return(client) }

    context 'with record' do
      before { allow(client).to receive(:get_task).with(id).and_return(resp) }
      before { allow(described_class).to receive(:new).with(resp).and_return(task) }
      it { is_expected.to eq(task) }
    end

    context 'with API temporarily unavailable' do
      before do
        call_count = 0
        allow(client).to receive(:get_task).with(id) do
          call_count += 1
          call_count > 1 ? resp : raise(Google::Gax::UnavailableError, 'msg')
        end
        allow(described_class).to receive(:new).with(resp).and_return(task)
      end

      it { is_expected.to eq(task) }
    end

    context 'with invalid id' do
      before { allow(client).to receive(:get_task).with(id).and_raise(Google::Gax::RetryError, 'msg') }
      it { is_expected.to be_nil }
    end
  end

  describe '.create' do
    subject(:api_create) { described_class.create(job_payload) }

    let(:id) { '123' }
    let(:queue) { 'some-queue' }
    let(:resp) { instance_double('Google::Cloud::Tasks::V2beta3::Task') }
    let(:task) { instance_double(described_class.to_s) }
    let(:expected_payload) do
      payload = JSON.parse(job_payload.to_json, symbolize_names: true)
      payload.delete(:queue)
      payload[:schedule_time] = described_class.format_schedule_time(job_payload[:schedule_time])
      payload[:http_request][:headers]['Content-Type'] = 'text/json'
      payload[:http_request][:headers]['Content-Transfer-Encoding'] = 'Base64'
      payload[:http_request][:body] = Base64.encode64(job_payload[:http_request][:body])
      payload
    end

    before { allow(described_class).to receive(:queue_path).with(job_payload[:queue]).and_return(queue) }
    before { allow(described_class).to receive(:client).and_return(client) }

    context 'with record' do
      before { allow(client).to receive(:create_task).with(queue, expected_payload).and_return(resp) }
      before { allow(described_class).to receive(:new).with(resp).and_return(task) }
      it { is_expected.to eq(task) }
    end

    context 'with API temporarily unavailable' do
      before do
        call_count = 0
        allow(client).to receive(:create_task).with(queue, expected_payload) do
          call_count += 1
          call_count > 1 ? resp : raise(Google::Gax::UnavailableError, 'msg')
        end
        allow(described_class).to receive(:new).with(resp).and_return(task)
      end

      it { is_expected.to eq(task) }
    end

    context 'with invalid task parameters' do
      before do
        allow(client).to receive(:create_task)
          .with(queue, expected_payload)
          .and_raise(Google::Gax::RetryError, 'msg')
      end
      it { expect { api_create }.to raise_error(Google::Gax::RetryError) }
    end
  end

  describe '.delete' do
    subject { described_class.delete(id) }

    let(:id) { '123' }
    let(:resp) { instance_double('Google::Cloud::Tasks::V2beta3::Task') }

    before { allow(described_class).to receive(:client).and_return(client) }

    context 'with record' do
      before { allow(client).to receive(:delete_task).with(id).and_return(resp) }
      it { is_expected.to eq(resp) }
    end

    context 'with API temporarily unavailable' do
      before do
        call_count = 0
        allow(client).to receive(:delete_task).with(id) do
          call_count += 1
          call_count > 1 ? resp : raise(Google::Gax::UnavailableError, 'msg')
        end
      end

      it { is_expected.to eq(resp) }
    end

    context 'with invalid id' do
      before { allow(client).to receive(:delete_task).with(id).and_raise(Google::Gax::RetryError, 'msg') }
      it { is_expected.to be_nil }
    end

    context 'with non-existing id (grpc error)' do
      before { allow(client).to receive(:delete_task).with(id).and_raise(GRPC::NotFound, 'msg') }
      it { is_expected.to be_nil }
    end

    context 'with non-existing id (Gax error)' do
      before { allow(client).to receive(:delete_task).with(id).and_raise(Google::Gax::NotFoundError, 'msg') }
      it { is_expected.to be_nil }
    end

    context 'with non-existing id (permission error)' do
      before { allow(client).to receive(:delete_task).with(id).and_raise(Google::Gax::PermissionDeniedError, 'msg') }
      it { is_expected.to be_nil }
    end
  end

  describe '.new' do
    subject { described_class.new(resp) }

    let(:resp) { instance_double('Google::Cloud::Tasks::V2beta3::Task') }

    it { is_expected.to have_attributes(gcp_task: resp) }
  end

  describe '#relative_queue' do
    subject { described_class.new(resp).relative_queue }

    let(:resp) { instance_double('Google::Cloud::Tasks::V2beta3::Task', name: task_name, to_h: resp_payload) }
    let(:resp_payload) { job_payload.merge(schedule_time: { seconds: job_payload[:schedule_time] }) }

    it { is_expected.to eq(relative_queue) }
  end

  describe '#to_h' do
    subject { described_class.new(resp).to_h }

    let(:retries) { 3 }
    let(:resp_payload) do
      job_payload.merge(
        schedule_time: { seconds: job_payload[:schedule_time] },
        response_count: retries
      )
    end
    let(:resp) do
      instance_double(
        'Google::Cloud::Tasks::V2beta3::Task',
        name: task_name,
        to_h: resp_payload
      )
    end

    it { is_expected.to eq(job_payload.merge(id: task_name, retries: retries)) }
  end
end
