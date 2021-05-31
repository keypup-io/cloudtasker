# frozen_string_literal: true

RSpec.describe Cloudtasker::Worker do
  let(:worker_class) { TestWorker }

  describe '.from_json' do
    subject { described_class.from_json(serialized_worker) }

    let(:worker_hash) { { 'foo' => 'bar' } }
    let(:serialized_worker) { worker_hash.to_json }
    let(:worker) { instance_double('TestWorker') }

    before { allow(described_class).to receive(:from_hash).with(worker_hash).and_return(worker) }

    context 'with valid json' do
      it { is_expected.to eq(worker) }
    end

    context 'with invalid json' do
      let(:serialized_worker) { '-' }

      it { is_expected.to be_nil }
    end
  end

  describe '.from_hash' do
    subject { described_class.from_hash(worker_hash) }

    let(:task_id) { '456' }
    let(:job_id) { '123' }
    let(:job_args) { [1, { 'foo' => 'bar' }] }
    let(:job_meta) { { foo: 'bar' } }
    let(:job_retries) { 3 }
    let(:job_queue) { 'critical' }
    let(:worker_class_name) { worker_class.to_s }
    let(:worker_hash) do
      {
        'worker' => worker_class_name,
        'job_id' => job_id,
        'job_args' => job_args,
        'job_meta' => job_meta,
        'job_retries' => job_retries,
        'job_queue' => job_queue,
        'task_id' => task_id
      }
    end

    context 'with valid worker' do
      let(:expected_attrs) do
        {
          job_queue: job_queue,
          job_id: job_id,
          job_args: job_args,
          job_meta: eq(job_meta),
          job_retries: job_retries,
          task_id: task_id
        }
      end

      it { is_expected.to be_a(worker_class) }
      it { is_expected.to have_attributes(expected_attrs) }
    end

    context 'with invalid worker' do
      let(:worker_class) { TestNonWorker }

      it { is_expected.to be_nil }
    end

    context 'with invalid class' do
      let(:worker_class_name) { 'Foo' }

      it { is_expected.to be_nil }
    end

    context 'with nil' do
      let(:worker_hash) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe '.perform_at' do
    subject { worker_class.perform_at(time_at, arg1, arg2) }

    let(:time_at) { Time.now }
    let(:arg1) { 1 }
    let(:arg2) { 2 }
    let(:resp) { instance_double('Cloudtasker::CloudTask') }

    before { allow(worker_class).to receive(:schedule).with(time_at: time_at, args: [arg1, arg2]).and_return(resp) }

    it { is_expected.to eq(resp) }
  end

  describe '.perform_in' do
    subject { worker_class.perform_in(delay, arg1, arg2) }

    let(:delay) { 10 }
    let(:arg1) { 1 }
    let(:arg2) { 2 }
    let(:resp) { instance_double('Cloudtasker::CloudTask') }

    before { allow(worker_class).to receive(:schedule).with(time_in: delay, args: [arg1, arg2]).and_return(resp) }

    it { is_expected.to eq(resp) }
  end

  describe '.perform_async' do
    subject { worker_class.perform_async(arg1, arg2) }

    let(:arg1) { 1 }
    let(:arg2) { 2 }
    let(:resp) { instance_double('Cloudtasker::CloudTask') }

    before { allow(worker_class).to receive(:schedule).with(args: [arg1, arg2]).and_return(resp) }
    it { is_expected.to eq(resp) }
  end

  describe '.schedule' do
    subject { worker_class.schedule(**opts) }

    let(:queue) { 'some-queue' }
    let(:delay) { 10 }
    let(:arg1) { 1 }
    let(:arg2) { 2 }
    let(:task) { instance_double('Cloudtasker::WorkerHandler') }
    let(:resp) { instance_double('Cloudtasker::CloudTask') }
    let(:worker) { instance_double(worker_class.to_s) }

    before { allow(worker_class).to receive(:new).with(job_queue: queue, job_args: [arg1, arg2]).and_return(worker) }

    context 'with time_in' do
      let(:opts) { { time_in: delay, args: [arg1, arg2], queue: queue } }

      before { allow(worker).to receive(:schedule).with(interval: delay).and_return(resp) }
      it { is_expected.to eq(resp) }
    end

    context 'with time_at' do
      let(:opts) { { time_at: delay, args: [arg1, arg2], queue: queue } }

      before { allow(worker).to receive(:schedule).with(time_at: delay).and_return(resp) }
      it { is_expected.to eq(resp) }
    end
  end

  describe '.cloudtasker_options_hash' do
    subject { worker_class.cloudtasker_options_hash }

    let(:opts) { { foo: 'bar' } }
    let!(:original_opts) { worker_class.cloudtasker_options_hash }

    before { worker_class.cloudtasker_options(opts) }
    after { worker_class.cloudtasker_options(original_opts) }
    it { is_expected.to eq(Hash[opts.map { |k, v| [k.to_sym, v] }]) }
  end

  describe '.max_retries' do
    subject { worker_class.max_retries }

    let(:opts) { {} }
    let!(:original_opts) { worker_class.cloudtasker_options_hash }

    before { worker_class.cloudtasker_options(opts) }
    after { worker_class.cloudtasker_options(original_opts) }

    context 'with value configured locally' do
      let(:retries) { Cloudtasker.config.max_retries - 5 }
      let(:opts) { { max_retries: retries } }

      it { is_expected.to eq(retries) }
    end

    context 'with value configured globally' do
      it { is_expected.to eq(Cloudtasker.config.max_retries) }
    end
  end

  describe '.new' do
    subject { worker_class.new(**worker_args) }

    let(:task_id) { SecureRandom.uuid }
    let(:id) { SecureRandom.uuid }
    let(:args) { [1, 2] }
    let(:meta) { { foo: 'bar' } }
    let(:retries) { 3 }
    let(:queue) { 'critical' }

    context 'without args' do
      let(:worker_args) { {} }
      let(:expected_attrs) do
        {
          job_queue: 'default',
          job_args: [],
          job_id: be_present,
          job_retries: 0,
          task_id: nil
        }
      end

      it { is_expected.to have_attributes(expected_attrs) }
    end

    context 'with args' do
      let(:worker_args) do
        {
          job_queue: queue,
          job_args: args,
          job_id: id,
          job_meta: meta,
          job_retries: retries,
          task_id: task_id
        }
      end
      let(:expected_args) do
        {
          job_queue: queue,
          job_args: args,
          job_id: id,
          job_meta: eq(meta),
          job_retries: retries,
          task_id: task_id
        }
      end

      it { is_expected.to have_attributes(expected_args) }
    end
  end

  describe '#job_class_name' do
    subject { worker.job_class_name }

    let(:worker) { worker_class.new }

    it { is_expected.to eq(worker.class.to_s) }
  end

  describe '#job_queue' do
    subject { worker.job_queue }

    let(:worker_queue) { nil }
    let(:worker) { worker_class.new(job_queue: worker_queue) }

    context 'with no queue specified' do
      it { is_expected.to eq('default') }
    end

    context 'with queue specified at class level' do
      let(:opts) { { queue: 'real-time' } }

      before { allow(worker_class).to receive(:cloudtasker_options_hash).and_return(opts) }
      it { is_expected.to eq(opts[:queue]) }
    end

    context 'with queue specified on worker' do
      let(:worker_queue) { 'critical' }

      it { is_expected.to eq(worker_queue) }
    end
  end

  describe '#dispatch_deadline' do
    subject { worker.dispatch_deadline }

    let(:worker) { worker_class.new }

    context 'with no value configured' do
      it { is_expected.to eq(Cloudtasker.config.dispatch_deadline) }
    end

    context 'with global value' do
      let(:dispatch_deadline) { 16 * 60 }

      before { allow(Cloudtasker.config).to receive(:dispatch_deadline).and_return(dispatch_deadline) }
      it { is_expected.to eq(dispatch_deadline) }
    end

    context 'with worker-specific value' do
      let(:dispatch_deadline) { 16 * 60 }
      let(:opts_hash) { { dispatch_deadline: dispatch_deadline } }

      before { allow(worker_class).to receive(:cloudtasker_options_hash).and_return(opts_hash) }
      it { is_expected.to eq(dispatch_deadline) }
    end

    context 'with configured value too low' do
      let(:dispatch_deadline) { Cloudtasker::Config::MIN_DISPATCH_DEADLINE - 5 }

      before { allow(Cloudtasker.config).to receive(:dispatch_deadline).and_return(dispatch_deadline) }
      it { is_expected.to eq(Cloudtasker::Config::MIN_DISPATCH_DEADLINE) }
    end

    context 'with configured value too high' do
      let(:dispatch_deadline) { Cloudtasker::Config::MAX_DISPATCH_DEADLINE + 5 }

      before { allow(Cloudtasker.config).to receive(:dispatch_deadline).and_return(dispatch_deadline) }
      it { is_expected.to eq(Cloudtasker::Config::MAX_DISPATCH_DEADLINE) }
    end
  end

  describe '#logger' do
    subject { worker.logger }

    let(:worker) { worker_class.new(job_args: [1, 2]) }

    it { is_expected.to be_a(Cloudtasker::WorkerLogger) }
    it { is_expected.to have_attributes(worker: worker) }
  end

  describe '#schedule_time' do
    subject { worker.schedule_time(interval: interval, time_at: time_at) }

    let(:worker) { worker_class.new }
    let(:interval) { nil }
    let(:time_at) { nil }

    context 'with no args' do
      it { is_expected.to be_nil }
    end

    context 'with interval' do
      let(:interval) { 10 }
      let(:expected_time) { Time.now.to_i + interval }

      around { |e| Timecop.freeze { e.run } }
      it { is_expected.to eq(expected_time) }
    end

    context 'with time_at' do
      let(:time_at) { Time.now }

      it { is_expected.to eq(time_at.to_i) }
    end

    context 'with time_at and interval' do
      let(:time_at) { Time.now }
      let(:interval) { 50 }
      let(:expected_time) { time_at.to_i + interval }

      it { is_expected.to eq(expected_time) }
    end
  end

  describe '#schedule' do
    subject { worker.schedule(interval: delay, time_at: time_at) }

    let(:time_at) { Time.now }
    let(:delay) { 10 }
    let(:arg1) { 1 }
    let(:arg2) { 2 }
    let(:task) { instance_double('Cloudtasker::WorkerHandler') }
    let(:resp) { instance_double('Cloudtasker::CloudTask') }
    let(:worker) { worker_class.new(job_args: [1, 2]) }
    let(:cal_time_at) { Time.now + 3600 }

    before do
      allow(worker).to receive(:schedule_time).with(interval: delay, time_at: time_at).and_return(cal_time_at)
      allow(Cloudtasker::WorkerHandler).to receive(:new).with(worker).and_return(task)
      allow(task).to receive(:schedule).with(time_at: cal_time_at).and_return(resp)
    end

    it { is_expected.to eq(resp) }

    context 'with client middleware chain' do
      before { Cloudtasker.config.client_middleware.add(TestMiddleware) }
      after { expect(worker.middleware_called).to be_truthy }
      after { expect(worker.middleware_opts).to eq(time_at: cal_time_at) }
      it { is_expected.to eq(resp) }
    end
  end

  describe '#execute' do
    subject(:execute) { worker.execute }

    let(:worker) { worker_class.new(job_args: args, job_id: SecureRandom.uuid) }
    let(:args) { [1, 2] }
    let(:resp) { 'some-result' }

    context 'with no middleware chain' do
      before { allow(worker).to receive(:perform).with(*args).and_return(resp) }
      before { expect(worker).to have_attributes(perform_started_at: nil, perform_ended_at: nil) }
      after { expect(worker).to have_attributes(perform_started_at: be_a(Time), perform_ended_at: be_a(Time)) }
      it { is_expected.to eq(resp) }
    end

    context 'with server middleware chain' do
      before { allow(worker).to receive(:perform).with(*args).and_return(resp) }
      before { expect(worker).to have_attributes(perform_started_at: nil, perform_ended_at: nil) }
      before { Cloudtasker.config.server_middleware.add(TestMiddleware) }
      after { expect(worker.middleware_called).to be_truthy }
      after { expect(worker).to have_attributes(perform_started_at: be_a(Time), perform_ended_at: be_a(Time)) }
      it { is_expected.to eq(resp) }
    end

    context 'with runtime error' do
      let(:error) { StandardError.new('some-message') }

      before { allow(worker).to receive(:perform).and_raise(error) }
      before { allow(worker).to receive(:on_error) }
      after { expect(worker).to have_received(:on_error).with(error) }
      it { expect { execute }.to raise_error(error) }
    end

    context 'with dying job' do
      let(:error) { StandardError.new('some-message') }

      before { worker.job_retries = worker_class.max_retries }
      before { allow(worker).to receive(:perform).and_raise(error) }
      before { allow(worker).to receive(:on_error) }
      before { allow(worker).to receive(:on_dead) }
      after { expect(worker).to have_received(:on_error).with(error) }
      after { expect(worker).to have_received(:on_dead).with(error) }
      it { expect { execute }.to raise_error(Cloudtasker::DeadWorkerError) }
    end

    context 'with dead job' do
      let(:error) { StandardError.new('some-message') }

      before { worker.job_retries = worker_class.max_retries + 1 }
      before { allow(worker).to receive(:perform) }
      before { allow(worker).to receive(:on_error) }
      before { allow(worker).to receive(:on_dead) }
      after { expect(worker).not_to have_received(:perform) }
      after { expect(worker).not_to have_received(:on_error) }
      after { expect(worker).to have_received(:on_dead).with(be_a(Cloudtasker::DeadWorkerError)) }
      it { expect { execute }.to raise_error(Cloudtasker::DeadWorkerError) }
    end

    context 'with missing worker arguments' do
      let(:args) { [] }

      it { expect { execute }.to raise_error(Cloudtasker::DeadWorkerError) }
    end
  end

  describe '#reenqueue' do
    subject { worker.reenqueue(delay) }

    let(:delay) { 10 }
    let(:worker) { worker_class.new(job_args: args) }
    let(:args) { [1, 2] }

    let(:resp) { instance_double('Cloudtasker::CloudTask') }

    before { allow(worker).to receive(:schedule).with(interval: delay).and_return(resp) }
    after { expect(worker.job_reenqueued).to be_truthy }
    it { is_expected.to eq(resp) }
  end

  describe '#new_instance' do
    subject(:new_instance) { worker.new_instance }

    let(:job_args) { [1, 2] }
    let(:job_meta) { { foo: 'bar' } }
    let(:job_queue) { 'critical' }
    let(:worker) { worker_class.new(job_args: job_args, job_meta: job_meta, job_queue: job_queue) }

    it { is_expected.to have_attributes(job_queue: job_queue, job_args: job_args, job_meta: eq(job_meta)) }
    it { expect(new_instance.job_id).not_to eq(worker.job_id) }
  end

  describe '#to_h' do
    subject { worker.to_h }

    let(:task_id) { SecureRandom.uuid }
    let(:job_args) { [1, 2] }
    let(:job_meta) { { foo: 'bar' } }
    let(:job_retries) { 3 }
    let(:worker) do
      worker_class.new(
        job_args: job_args,
        job_meta: job_meta,
        job_retries: job_retries,
        task_id: task_id
      )
    end
    let(:expected_hash) do
      {
        worker: worker.class.to_s,
        job_id: worker.job_id,
        job_args: worker.job_args,
        job_meta: worker.job_meta.to_h,
        job_retries: worker.job_retries,
        job_queue: worker.job_queue,
        task_id: task_id
      }
    end

    it { is_expected.to eq(expected_hash) }
  end

  describe '#to_json' do
    subject { worker.to_json }

    let(:worker) { worker_class.new(job_args: [1, 2], job_meta: { foo: 'bar' }) }

    it { is_expected.to eq(worker.to_h.to_json) }
  end

  describe '#==' do
    subject { worker }

    let(:worker) { worker_class.new(job_args: [1, 2], job_meta: { foo: 'bar' }) }

    context 'with same job_id' do
      it { is_expected.to eq(worker_class.new(job_id: worker.job_id)) }
    end

    context 'with different job_id' do
      it { is_expected.not_to eq(worker_class.new(job_id: worker.job_id + 'a')) }
    end

    context 'with different object' do
      it { is_expected.not_to eq('foo') }
    end
  end

  describe '#job_max_retries' do
    subject { worker.job_max_retries }

    let(:worker) { worker_class.new(job_args: [1, 2]) }

    context 'with max_retries method defined' do
      let(:max_retries) { 10 }

      before { expect(worker).to receive(:max_retries).with(*worker.job_args).and_return(max_retries) }
      it { is_expected.to eq(max_retries) }
    end

    context 'with max_retries returning nil' do
      before { expect(worker).to receive(:max_retries).with(*worker.job_args).and_return(nil) }
      it { is_expected.to eq(worker_class.max_retries) }
    end

    context 'without max_retries method defined' do
      it { is_expected.to eq(worker_class.max_retries) }
    end
  end

  describe '#job_must_die?' do
    subject { worker }

    let(:worker) { worker_class.new(job_retries: 5) }

    before { allow(worker).to receive(:job_max_retries).and_return(max_retries) }

    context 'with job retries exceeded' do
      let(:max_retries) { 5 }

      it { is_expected.to be_job_must_die }
    end

    context 'with job retrieve below max' do
      let(:max_retries) { 10 }

      it { is_expected.not_to be_job_must_die }
    end
  end

  describe '#job_dead?' do
    subject { worker }

    let(:worker) { worker_class.new(job_retries: 5) }

    before { allow(worker).to receive(:job_max_retries).and_return(max_retries) }

    context 'with job retries exceeded' do
      let(:max_retries) { 4 }

      it { is_expected.to be_job_dead }
    end

    context 'with job retrieve below or equal to max' do
      let(:max_retries) { 5 }

      it { is_expected.not_to be_job_dead }
    end
  end

  describe '#arguments_missing?' do
    subject { worker }

    let(:job_args) { [1, 2, 3] }
    let(:worker) { worker_class.new(job_args: job_args) }

    context 'with job arguments' do
      it { is_expected.not_to be_arguments_missing }
    end

    context 'with no job arguments required' do
      let(:job_args) { [] }

      before { def worker.perform; end }
      it { is_expected.not_to be_arguments_missing }
    end

    context 'with perform method accepting any arg' do
      let(:job_args) { [] }

      before { def worker.perform(*_args); end }
      it { is_expected.not_to be_arguments_missing }
    end

    context 'with job arguments missing' do
      let(:job_args) { [] }

      before { def worker.perform(_arg1, arg2); end }
      it { is_expected.to be_arguments_missing }
    end
  end

  describe '#job_duration' do
    subject { worker.job_duration }

    let(:worker) { worker_class.new }
    let(:now) { Time.now }
    let(:perform_started_at) { now - 10.0005 }
    let(:perform_ended_at) { now }

    before do
      worker.perform_started_at = perform_started_at
      worker.perform_ended_at = perform_ended_at
    end

    context 'with timestamps set' do
      it { is_expected.to eq((perform_ended_at - perform_started_at).ceil(3)) }
    end

    context 'with no perform_started_at' do
      let(:perform_started_at) { nil }

      it { is_expected.to eq(0.0) }
    end

    context 'with no perform_ended_at' do
      let(:perform_ended_at) { nil }

      it { is_expected.to eq(0.0) }
    end
  end

  describe '#run_worker_callback' do
    subject(:run_worker_callback) { worker.run_callback(callback, *args) }

    let(:worker) { worker_class.new }
    let(:callback) { :some_callback }
    let(:args) { [1, 'arg'] }
    let(:resp) { 'some-response' }

    before { allow(worker).to receive(callback).with(*args).and_return(resp) }
    it { is_expected.to eq(resp) }
  end
end
