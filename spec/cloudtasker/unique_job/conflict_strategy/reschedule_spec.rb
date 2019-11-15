# frozen_string_literal: true

require 'cloudtasker/unique_job/middleware'

RSpec.describe Cloudtasker::UniqueJob::ConflictStrategy::Reschedule do
  let(:worker) { TestWorker.new(job_args: [1, 2]) }
  let(:job) { Cloudtasker::UniqueJob::Job.new(worker) }
  let(:strategy) { described_class.new(job) }

  it_behaves_like Cloudtasker::UniqueJob::ConflictStrategy::BaseStrategy

  describe '#on_schedule' do
    it { expect { |b| strategy.on_schedule(&b) }.to yield_control }
  end

  describe '#on_execute' do
    subject { strategy.on_execute }

    before { allow(worker).to receive(:reenqueue).with(described_class::RESCHEDULE_DELAY).and_return(true) }
    after { expect(worker).to have_received(:reenqueue) }

    it { is_expected.to be_truthy }
    it { expect { |b| strategy.on_execute(&b) }.not_to yield_control }
  end
end
