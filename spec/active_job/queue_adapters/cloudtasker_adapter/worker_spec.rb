# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../shared/active_job/instantiation_context'

RSpec.describe ActiveJob::QueueAdapters::CloudtaskerAdapter::Worker do
  include_context 'of Cloudtasker ActiveJob instantiation'

  subject(:worker) { described_class.new example_worker_args }

  let(:example_unreconstructed_job_serialization) { example_job.serialize }

  describe '#perform' do
    it "calls 'ActiveJob::Base.execute' with the job serialization" do
      expect(ActiveJob::Base).to receive(:execute)
        .with example_job_serialization

      worker.perform(example_unreconstructed_job_serialization)
    end
  end
end
