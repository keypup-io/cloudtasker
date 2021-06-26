# frozen_string_literal: true

require 'cloudtasker/backend/redis_task'

RSpec.describe Cloudtasker::Backend::RedisTask do
  let(:redis) { described_class.redis }
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
      dispatch_deadline: 500,
      schedule_time: 2,
      retries: 3,
      queue: 'critical'
    }
  end
  let(:task_id) { '1234' }
  let(:task) { described_class.new(**job_payload.merge(id: task_id)) }

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
    subject { described_class.all.sort_by(&:id) }

    let!(:tasks) { 2.times.map { described_class.create(job_payload) }.sort_by(&:id) }

    context 'with task set available' do
      after { expect(redis.smembers(described_class.key).sort).to eq(tasks.map(&:id)) }
      it { is_expected.to eq(tasks) }
    end

    context 'without task set available' do
      before { redis.del(described_class.key) }
      after { expect(redis.smembers(described_class.key).sort).to eq(tasks.map(&:id)) }
      it { is_expected.to eq(tasks) }
    end
  end

  describe '.ready_to_process' do
    subject { described_class.ready_to_process(queue) }

    let(:queue) { nil }
    let(:tasks) do
      [
        described_class.new(**job_payload.merge(id: 1, queue: 'critical')),
        described_class.new(**job_payload.merge(id: 2, queue: 'default')),
        described_class.new(**job_payload.merge(id: 3, schedule_time: Time.now + 3600))
      ]
    end

    before { allow(described_class).to receive(:all).and_return(tasks) }

    context 'with no queue specified' do
      it { is_expected.to eq(tasks[0..1]) }
    end

    context 'with queue specified' do
      let(:queue) { 'critical' }

      it { is_expected.to eq([tasks[0]]) }
    end
  end

  describe '.pop' do
    subject { described_class.pop(queue) }

    let(:queue) { 'some-queue' }
    let(:tasks) do
      [
        described_class.new(**job_payload.merge(id: 1)),
        described_class.new(**job_payload.merge(id: 2))
      ]
    end

    before { allow(described_class).to receive(:ready_to_process).with(queue).and_return(tasks) }
    before { allow(tasks[0]).to receive(:destroy) }
    after { expect(tasks[0]).to have_received(:destroy) }
    it { is_expected.to eq(tasks[0]) }
  end

  describe '.create' do
    subject { described_class.all.first }

    let(:expected_attrs) do
      job_payload.merge(schedule_time: Time.at(job_payload[:schedule_time]))
    end

    before do
      allow(SecureRandom).to receive(:uuid).and_return(task_id)
      described_class.create(job_payload)
    end
    after { expect(redis.smembers(described_class.key)).to eq([task_id]) }

    it { is_expected.to have_attributes(expected_attrs) }
  end

  describe '.find' do
    subject { described_class.find(task_id) }

    let(:expected_record) { described_class.new(**job_payload.merge(id: task_id)) }

    context 'with record found' do
      before { allow(SecureRandom).to receive(:uuid).and_return(task_id) }
      before { described_class.create(job_payload) }
      it { is_expected.to eq(expected_record) }
    end

    context 'with invalid id' do
      let(:id) { '-' }

      it { is_expected.to be_nil }
    end
  end

  describe '.delete' do
    subject { described_class.find(task_id) }

    before do
      allow(SecureRandom).to receive(:uuid).and_return(task_id)
      described_class.create(job_payload)
      described_class.delete(task_id)
    end
    after { expect(redis.smembers(described_class.key)).to be_empty }

    it { is_expected.to be_nil }
  end

  describe '.new' do
    subject { described_class.new(**args) }

    let(:id) { '123' }
    let(:args) { job_payload.merge(id: id) }
    let(:expected_attrs) do
      job_payload.merge(id: id, schedule_time: Time.at(job_payload[:schedule_time]))
    end

    context 'with queue specified' do
      it { is_expected.to have_attributes(expected_attrs) }
    end

    context 'with no queue specified' do
      let(:args) { job_payload.merge(id: id, queue: nil) }

      it { is_expected.to have_attributes(expected_attrs.merge(queue: 'default')) }
    end
  end

  describe '#redis' do
    subject { task.redis }

    it { is_expected.to be_a(Cloudtasker::RedisClient) }
  end

  describe '#to_h' do
    subject { task.to_h }

    let(:expected_hash) do
      {
        id: task.id,
        http_request: task.http_request,
        schedule_time: task.schedule_time.to_i,
        retries: task.retries,
        queue: task.queue,
        dispatch_deadline: task.dispatch_deadline
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
    let(:task) { described_class.create(job_payload).tap(&:destroy) }
    let(:retries) { job_payload[:retries] + 1 }
    let(:opts) { {} }
    let(:expected_attrs) do
      job_payload.merge(retries: retries, schedule_time: Time.at(Time.now.to_i + delay))
    end

    before do
      Timecop.freeze
      task.retry_later(delay, opts)
      expect(redis.smembers(described_class.key)).to eq([task.id])
    end
    after { Timecop.return }

    it { is_expected.to have_attributes(expected_attrs) }

    context 'with is_error: false' do
      let(:opts) { { is_error: false } }
      let(:retries) { job_payload[:retries] }

      it { is_expected.to have_attributes(expected_attrs) }
    end
  end

  describe '#destroy' do
    subject { task.destroy }

    let!(:task) { described_class.create(job_payload) }

    before { expect(described_class).to receive(:delete).with(task.id).and_return(true) }
    it { is_expected.to be_truthy }
  end

  describe '#deliver' do
    subject { task.deliver }

    let(:status) { 200 }
    let!(:http_stub) do
      stub_request(:post, job_payload.dig(:http_request, :url))
        .with(
          headers: {
            Cloudtasker::Config::TASK_ID_HEADER => task_id,
            Cloudtasker::Config::RETRY_HEADER => job_payload[:retries]
          },
          body: job_payload.dig(:http_request, :body)
        )
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
      it { is_expected.to eq(described_class.new(**job_payload.merge(id: task_id))) }
    end

    context 'with different id' do
      it { is_expected.not_to eq(described_class.new(**job_payload.merge(id: task_id + 'a'))) }
    end

    context 'with different object' do
      it { is_expected.not_to eq('foo') }
    end
  end
end
