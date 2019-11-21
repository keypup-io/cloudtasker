# frozen_string_literal: true

require 'cloudtasker/backend/google_cloud_task'

RSpec.describe Cloudtasker::Backend::GoogleCloudTask do
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
      schedule_time: 2
    }
  end
  let(:config) { Cloudtasker.config }
  let(:client) { instance_double('Google::Cloud::Tasks::V2beta3::Task') }

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
    subject { described_class.queue_path }

    let(:queue) { 'some-queue' }
    let(:expected_args) do
      [
        config.gcp_project_id,
        config.gcp_location_id,
        config.gcp_queue_id
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

    context 'with invalid id' do
      before { allow(client).to receive(:get_task).with(id).and_raise(Google::Gax::RetryError, 'msg') }
      it { is_expected.to be_nil }
    end
  end

  describe '.create' do
    subject { described_class.create(job_payload) }

    let(:id) { '123' }
    let(:queue) { 'some-queue' }
    let(:resp) { instance_double('Google::Cloud::Tasks::V2beta3::Task') }
    let(:task) { instance_double(described_class.to_s) }
    let(:expected_payload) do
      job_payload.merge(
        schedule_time: described_class.format_schedule_time(job_payload[:schedule_time])
      )
    end

    before { allow(described_class).to receive(:queue_path).and_return(queue) }
    before { allow(described_class).to receive(:client).and_return(client) }

    context 'with record' do
      before { allow(client).to receive(:create_task).with(queue, expected_payload).and_return(resp) }
      before { allow(described_class).to receive(:new).with(resp).and_return(task) }
      it { is_expected.to eq(task) }
    end

    context 'with error' do
      before do
        allow(client).to receive(:create_task).with(queue, expected_payload).and_raise(Google::Gax::RetryError, 'msg')
      end
      it { is_expected.to be_nil }
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

    context 'with invalid id' do
      before { allow(client).to receive(:delete_task).with(id).and_raise(Google::Gax::RetryError, 'msg') }
      it { is_expected.to be_nil }
    end
  end

  describe '.new' do
    subject { described_class.new(resp) }

    let(:resp) { instance_double('Google::Cloud::Tasks::V2beta3::Task') }

    it { is_expected.to have_attributes(gcp_task: resp) }
  end

  describe '#to_h' do
    subject { described_class.new(resp).to_h }

    let(:id) { '123' }
    let(:resp) do
      instance_double(
        'Google::Cloud::Tasks::V2beta3::Task',
        name: id,
        to_h: job_payload.merge(schedule_time: { seconds: job_payload[:schedule_time] })
      )
    end

    it { is_expected.to eq(job_payload.merge(id: id)) }
  end
end
