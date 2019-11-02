# frozen_string_literal: true

RSpec.describe Cloudtasker::Task do
  let(:config) { Cloudtasker.config }
  let(:client) { instance_double('Google::Cloud::Tasks::V2beta3::CloudTasksClient') }
  let(:worker) { MyWorker }
  let(:args) { ['foo', 1] }
  let(:task) { described_class.new(worker: MyWorker, args: args) }

  describe 'creation' do
    subject { task }

    it { is_expected.to have_attributes(worker: worker, args: args) }
  end

  describe '.client' do
    subject { described_class.client }

    before { allow(Google::Cloud::Tasks).to receive(:new).with(version: :v2beta3).and_return(client) }

    it { is_expected.to eq(client) }
  end

  describe '#client' do
    subject { task.client }

    before { allow(described_class).to receive(:client).and_return(client) }

    it { is_expected.to eq(client) }
  end

  describe '#config' do
    subject { task.config }

    it { is_expected.to eq(Cloudtasker.config) }
  end

  describe '#queue_path' do
    subject { task.queue_path }

    let(:queue_path) { 'my/queue' }

    before do
      allow(described_class).to receive(:client).and_return(client)
      allow(client).to receive(:queue_path).with(
        config.gcp_project_id,
        config.gcp_location_id,
        config.gcp_queue_id
      ).and_return(queue_path)
    end

    it { is_expected.to eq(queue_path) }
  end

  describe '#verification_token' do
    subject { task.verification_token }

    let(:expected_token) { JWT.encode({ iat: Time.now.to_i }, config.secret, described_class::JWT_ALG) }

    around { |e| Timecop.freeze { e.run } }

    it { is_expected.to eq(expected_token) }
  end

  describe '#task_payload' do
    subject { task.task_payload }

    let(:expected_payload) do
      {
        http_request: {
          http_method: 'POST',
          url: config.processor_url,
          headers: {
            'Content-Type' => 'application/json',
            'Authorization' => "Bearer #{task.verification_token}"
          },
          body: task.worker_payload.to_json
        }
      }
    end

    around { |e| Timecop.freeze { e.run } }

    it { is_expected.to eq(expected_payload) }
  end

  describe '#worker_payload' do
    subject { task.worker_payload }

    let(:expected_payload) { { worker: worker.to_s, args: args } }

    it { is_expected.to eq(expected_payload) }
  end

  describe '#schedule_time' do
    subject { task.schedule_time(interval) }

    context 'with no interval' do
      let(:interval) { nil }

      it { is_expected.to be_nil }
    end

    context 'with negative interval' do
      let(:interval) { -1 }

      it { is_expected.to be_nil }
    end

    context 'with positive interval' do
      let(:interval) { 10 }
      let(:expected_time) do
        ts = Google::Protobuf::Timestamp.new
        ts.seconds = Time.now.to_i + interval.to_i
        ts
      end

      around { |e| Timecop.freeze { e.run } }
      it { is_expected.to eq(expected_time) }
    end
  end

  describe '#schedule' do
    subject { task.schedule(**attrs) }

    let(:attrs) { {} }
    let(:queue_path) { 'some-queue' }
    let(:expected_payload) { task.task_payload }
    let(:resp) { instance_double('Class: Google::Cloud::Tasks::V2beta3::Task') }

    around { |e| Timecop.freeze { e.run } }
    before { allow(task).to receive(:queue_path).and_return(queue_path) }
    before { allow(task).to receive(:client).and_return(client) }
    before { allow(client).to receive(:create_task).with(queue_path, expected_payload).and_return(resp) }

    context 'with no delay' do
      it { is_expected.to eq(resp) }
    end

    context 'with scheduled time' do
      let(:attrs) { { interval: 10 } }
      let(:expected_payload) { task.task_payload.merge(schedule_time: task.schedule_time(attrs[:interval])) }

      it { is_expected.to eq(resp) }
    end
  end
end
