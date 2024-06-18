# frozen_string_literal: true

require 'cloudtasker/unique_job/middleware'

RSpec.describe Cloudtasker::UniqueJob::ConflictStrategy::Reject do
  let(:worker) { TestWorker.new(job_args: [1, 2]) }
  let(:job) { Cloudtasker::UniqueJob::Job.new(worker) }
  let(:strategy) { described_class.new(job) }

  it_behaves_like Cloudtasker::UniqueJob::ConflictStrategy::BaseStrategy

  describe '#on_schedule' do
    subject { strategy.on_schedule }

    it { is_expected.to be_falsey }
    it { expect { |b| strategy.on_schedule(&b) }.not_to yield_control }
  end

  describe '#on_execute' do
    subject { strategy.on_execute }

    it { is_expected.to be_falsey }
    it { expect { |b| strategy.on_execute(&b) }.not_to yield_control }
  end
end
