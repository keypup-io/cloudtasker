# frozen_string_literal: true

require 'cloudtasker/backend/redis_task'

RSpec.describe Cloudtasker::Backend::RedisTask do
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
  let(:task_id) { '1234' }
  let(:task) { described_class.new(job_payload.merge(id: task_id)) }

  describe '.redis' do
    subject { described_class.redis }

    it { is_expected.to eq(Cloudtasker::RedisClient) }
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

  describe '.all' do
    subject { described_class.all.sort_by(&:id) }

    let(:expected) do
      described_class.redis.keys.map do |gid|
        payload = described_class.redis.fetch(gid)
        described_class.new(payload.merge(id: gid.gsub(described_class.key(''), '')))
      end.sort_by(&:id)
    end

    before { 2.times { described_class.create(job_payload) } }
    it { is_expected.to eq(expected) }
  end

  describe '.ready_to_process' do
    subject { described_class.ready_to_process }

    let(:tasks) do
      [
        described_class.new(job_payload.merge(id: 1)),
        described_class.new(job_payload.merge(id: 2, schedule_time: Time.now + 3600))
      ]
    end

    before { allow(described_class).to receive(:all).and_return(tasks) }
    it { is_expected.to eq([tasks[0]]) }
  end

  describe '.pop' do
    subject { described_class.pop }

    let(:tasks) do
      [
        described_class.new(job_payload.merge(id: 1)),
        described_class.new(job_payload.merge(id: 2))
      ]
    end

    before { allow(described_class).to receive(:ready_to_process).and_return(tasks) }
    before { allow(tasks[0]).to receive(:destroy) }
    after { expect(tasks[0]).to have_received(:destroy) }
    it { is_expected.to eq(tasks[0]) }
  end

  describe '.create' do
    subject { described_class.all.first }

    let(:expected_attrs) do
      job_payload.merge(schedule_time: Time.at(job_payload[:schedule_time]))
    end

    before { described_class.create(job_payload) }
    it { is_expected.to have_attributes(expected_attrs) }
  end

  describe '.find' do
    subject { described_class.find(id) }

    let(:id) { described_class.redis.keys.first.gsub(described_class.key(''), '') }
    let(:expected_record) { described_class.new(job_payload.merge(id: id)) }

    context 'with record found' do
      before { described_class.create(job_payload) }
      it { is_expected.to eq(expected_record) }
    end

    context 'with invalid id' do
      let(:id) { '-' }

      it { is_expected.to be_nil }
    end
  end

  describe '.delete' do
    subject { described_class.find(id) }

    let(:id) { described_class.redis.keys.first.gsub(described_class.key(''), '') }

    before { described_class.create(job_payload) }
    before { described_class.delete(id) }
    it { is_expected.to be_nil }
  end

  describe '.new' do
    subject { described_class.new(job_payload.merge(id: id)) }

    let(:id) { '123' }
    let(:expected_attrs) do
      job_payload.merge(id: id, schedule_time: Time.at(job_payload[:schedule_time]))
    end

    it { is_expected.to have_attributes(expected_attrs) }
  end

  describe '#redis' do
    subject { task.redis }

    it { is_expected.to eq(Cloudtasker::RedisClient) }
  end

  describe '#to_h' do
    subject { task.to_h }

    let(:expected_hash) do
      {
        id: task.id,
        http_request: task.http_request,
        schedule_time: task.schedule_time.to_i
      }
    end

    it { is_expected.to eq(expected_hash) }
  end

  describe '#gid' do
    subject { task.gid }

    it { is_expected.to eq(described_class.key(task.id)) }
  end

  describe '#retry_later' do
    subject { described_class.all.first }

    let(:delay) { 3600 }
    let(:task) { described_class.create(job_payload) }

    before { Timecop.freeze }
    before { task.retry_later(delay) }
    after { Timecop.return }
    it { is_expected.to have_attributes(schedule_time: Time.at(Time.now.to_i + delay)) }
  end

  describe '#destroy' do
    subject { described_class.all.first }

    let!(:task) { described_class.create(job_payload) }

    before { task.destroy }
    it { is_expected.to be_nil }
  end

  describe '#deliver' do
    subject { task.deliver }

    let(:status) { 200 }
    let!(:http_stub) do
      stub_request(:post, job_payload.dig(:http_request, :url))
        .with(body: job_payload.dig(:http_request, :body))
        .to_return(status: status)
    end

    before do
      allow(task).to receive(:destroy).and_return(true)
      allow(task).to receive(:retry_later).with(described_class::RETRY_INTERVAL).and_return(true)
    end
    after { expect(http_stub).to have_been_requested }

    context 'with success' do
      after { expect(task).to have_received(:destroy) }
      after { expect(task).not_to have_received(:retry_later) }
      it { is_expected.to be_truthy }
    end

    context 'with failure' do
      let(:status) { 500 }

      after { expect(task).not_to have_received(:destroy) }
      after { expect(task).to have_received(:retry_later) }
      it { is_expected.to be_truthy }
    end
  end

  describe '#==' do
    subject { task }

    context 'with same id' do
      it { is_expected.to eq(described_class.new(job_payload.merge(id: task_id))) }
    end

    context 'with different id' do
      it { is_expected.not_to eq(described_class.new(job_payload.merge(id: task_id + 'a'))) }
    end

    context 'with different object' do
      it { is_expected.not_to eq('foo') }
    end
  end
end
