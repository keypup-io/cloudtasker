# frozen_string_literal: true

require 'spec_helper'

if defined?(Rails)
  RSpec.describe ActiveJob::QueueAdapters::CloudtaskerAdapter::JobWrapper do
    include_context 'of Cloudtasker ActiveJob instantiation'

    subject(:worker) { described_class.new(**example_job_wrapper_args.merge(task_id: '00000001')) }

    let(:example_job_serialization) do
      example_job.serialize.except('job_id', 'priority', 'queue_name', 'provider_job_id')
    end

    context 'when the CloudTask retry mechanism is used' do
      let(:example_unreconstructed_job_serialization) do
        example_job_serialization.except('job_id', 'queue_name', 'provider_job_id', 'executions', 'priority')
      end

      let(:example_reconstructed_job_serialization) do
        example_job_serialization.merge(
          'job_id' => worker.job_id,
          'queue_name' => worker.job_queue,
          'provider_job_id' => worker.task_id,
          'executions' => 0,
          'priority' => nil
        )
      end

      describe '#perform' do
        it "calls 'ActiveJob::Base.execute' with the job serialization" do
          expect(ActiveJob::Base).to receive(:execute).with(example_reconstructed_job_serialization)
          worker.perform(example_unreconstructed_job_serialization)
        end
      end
    end

    context 'when the ActiveJob retry mechanism is used' do
      around do |example|
        Cloudtasker.config.retry_mechanism = :active_job
        example.call
        Cloudtasker.config.retry_mechanism = :provider
      end

      before do
        example_job.executions = 1
      end

      let(:example_unreconstructed_job_serialization) do
        example_job_serialization.except('job_id', 'queue_name', 'provider_job_id', 'priority')
      end

      let(:example_reconstructed_job_serialization) do
        example_job_serialization.merge(
          'job_id' => worker.job_id,
          'executions' => 1,
          'queue_name' => worker.job_queue,
          'provider_job_id' => worker.task_id,
          'priority' => nil
        )
      end

      describe '#perform' do
        it "calls 'ActiveJob::Base.execute' with the job serialization" do
          expect(ActiveJob::Base).to receive(:execute).with(example_reconstructed_job_serialization)
          worker.perform(example_unreconstructed_job_serialization)
        end
      end
    end
  end
end
