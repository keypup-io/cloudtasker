# frozen_string_literal: true

require 'spec_helper'

if defined?(Rails)
  RSpec.describe ActiveJob::QueueAdapters::CloudtaskerAdapter do
    include_context 'of Cloudtasker ActiveJob instantiation'

    subject(:adapter) { described_class.new }

    let(:example_job_wrapper_double) do
      instance_double("#{described_class.name}::JobWrapper", example_job_wrapper_args)
        .tap { |double| allow(double).to receive(:schedule) }
    end

    around { |e| Timecop.freeze { e.run } }
    before { allow(described_class::JobWrapper).to receive(:new).and_return(example_job_wrapper_double) }

    shared_examples 'of instantiating a Cloudtasker JobWrapper from ActiveJob' do
      it 'instantiates a new CloudtaskerAdapter JobWrapper for the given job' do
        expect(described_class::JobWrapper).to receive(:new).with(example_job_wrapper_args)
        adapter.enqueue(example_job)
      end
    end

    describe '#enqueue' do
      include_examples 'of instantiating a Cloudtasker JobWrapper from ActiveJob'

      it 'enqueues the new CloudtaskerAdapter JobWrapper to execute' do
        expect(example_job_wrapper_double).to receive(:schedule)
        adapter.enqueue(example_job)
      end
    end

    describe '#enqueue_at' do
      let(:example_execution_timestamp) { 1.week.from_now.to_i }
      let(:expected_execution_time) { Time.at(example_execution_timestamp) }

      include_examples 'of instantiating a Cloudtasker JobWrapper from ActiveJob'

      it 'enqueues the new CloudtaskerAdapter JobWrapper to execute at the given time' do
        expect(example_job_wrapper_double).to receive(:schedule).with(time_at: expected_execution_time)
        adapter.enqueue_at(example_job, example_execution_timestamp)
      end
    end

    describe '#enqueue_after_transaction_commit?' do
      it { expect(adapter).to be_enqueue_after_transaction_commit }
    end
  end
end
