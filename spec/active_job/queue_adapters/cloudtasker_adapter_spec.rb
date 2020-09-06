# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ActiveJob::QueueAdapters::CloudtaskerAdapter do
  let :example_job_class do
    Class.new(ActiveJob::Base) do
      def self.name
        'ExampleJob'
      end
    end
  end

  let(:example_job_setup) { {} }
  let(:example_job_arguments) { [1, 'two', { three: 3 }] }
  let(:example_job) { example_job_class.new(*example_job_arguments) }
  let(:example_job_serialization) { example_job.serialize }

  let :expected_worker_args do
    {
      job_queue: example_job.queue_name,
      job_args: [example_job_serialization],
      job_id: example_job.job_id
    }
  end

  let :example_worker_double do
    instance_double(
      "#{described_class.name}::Worker",
      expected_worker_args
    ).tap { |double| allow(double).to receive(:schedule) }
  end

  before do
    allow(described_class::Worker).to receive(:new)
      .and_return example_worker_double
  end

  shared_examples 'of instantiating a Cloudtasker Worker from ActiveJob' do
    it 'instantiates a new CloudtaskerAdapter Worker for the given job' do
      expect(described_class::Worker).to receive(:new).with expected_worker_args

      subject.enqueue(example_job)
    end
  end

  describe '#enqueue' do
    include_examples 'of instantiating a Cloudtasker Worker from ActiveJob'

    it 'enqueues the new CloudtaskerAdapter Worker to execute' do
      expect(example_worker_double).to receive :schedule

      subject.enqueue(example_job)
    end
  end

  describe '#enqueue_at' do
    include_examples 'of instantiating a Cloudtasker Worker from ActiveJob'
    let(:example_execution_timestamp) { 1.week.from_now.to_f }
    let(:expected_execution_time) { Time.at example_execution_timestamp }

    it 'enqueues the new CloudtaskerAdapter Worker to execute at the given time' do
      expect(example_worker_double).to receive(:schedule)
        .with time_at: expected_execution_time

      subject.enqueue_at(example_job, example_execution_timestamp)
    end
  end
end
