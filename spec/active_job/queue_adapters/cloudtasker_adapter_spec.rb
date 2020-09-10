# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ActiveJob::QueueAdapters::CloudtaskerAdapter do
  include_context 'of Cloudtasker ActiveJob instantiation'

  subject(:adapter) { described_class.new }

  let :example_worker_double do
    instance_double(
      "#{described_class.name}::Worker",
      example_worker_args
    ).tap { |double| allow(double).to receive(:schedule) }
  end

  before do
    allow(described_class::Worker).to receive(:new)
      .and_return example_worker_double
  end

  shared_examples 'of instantiating a Cloudtasker Worker from ActiveJob' do
    it 'instantiates a new CloudtaskerAdapter Worker for the given job' do
      expect(described_class::Worker).to receive(:new).with example_worker_args

      adapter.enqueue(example_job)
    end
  end

  describe '#enqueue' do
    include_examples 'of instantiating a Cloudtasker Worker from ActiveJob'

    it 'enqueues the new CloudtaskerAdapter Worker to execute' do
      expect(example_worker_double).to receive :schedule

      adapter.enqueue(example_job)
    end
  end

  describe '#enqueue_at' do
    let(:example_execution_timestamp) { 1.week.from_now.to_f }
    let(:expected_execution_time) { Time.at example_execution_timestamp }

    include_examples 'of instantiating a Cloudtasker Worker from ActiveJob'

    it 'enqueues the new CloudtaskerAdapter Worker to execute at the given time' do
      expect(example_worker_double).to receive(:schedule)
        .with time_at: expected_execution_time

      adapter.enqueue_at(example_job, example_execution_timestamp)
    end
  end
end
