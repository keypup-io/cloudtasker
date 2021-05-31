# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ActiveJob::QueueAdapters::CloudtaskerAdapter::JobWrapper do
  include_context 'of Cloudtasker ActiveJob instantiation'

  subject :worker do
    described_class.new(**example_job_wrapper_args.merge(task_id: '00000001'))
  end

  let :example_unreconstructed_job_serialization do
    example_job_serialization.except(
      'job_id', 'queue_name', 'provider_job_id', 'executions', 'priority'
    )
  end

  let :example_reconstructed_job_serialization do
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
      expect(ActiveJob::Base).to receive(:execute)
        .with(example_reconstructed_job_serialization)

      worker.perform(example_unreconstructed_job_serialization)
    end
  end
end
