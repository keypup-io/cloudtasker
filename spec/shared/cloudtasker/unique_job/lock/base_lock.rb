# frozen_string_literal: true

require 'cloudtasker/unique_job/middleware'

RSpec.shared_examples Cloudtasker::UniqueJob::Lock::BaseLock do
  describe '.new' do
    subject { described_class.new(job) }

    let(:worker) { TestWorker.new(job_args: [1, 2], job_id: SecureRandom.uuid) }
    let(:job) { Cloudtasker::UniqueJob::Job.new(worker) }

    it { is_expected.to have_attributes(job: job) }
  end
end
