# frozen_string_literal: true

require 'cloudtasker/unique_job/middleware'

RSpec.describe Cloudtasker::UniqueJob::Middleware::Client do
  let(:middleware) { described_class.new }

  describe '#call' do
    let(:lock_instance) { instance_double(Cloudtasker::UniqueJob::Lock::UntilExecuted) }
    let(:worker) { instance_double(Cloudtasker::Worker) }
    let(:job) { instance_double(Cloudtasker::UniqueJob::Job) }

    before { allow(Cloudtasker::UniqueJob::Job).to receive(:new).with(worker).and_return(job) }
    before { allow(job).to receive(:lock_instance).and_return(lock_instance) }
    before { allow(lock_instance).to receive(:schedule).and_yield }
    it { expect { |b| middleware.call(worker, &b) }.to yield_control }
  end
end
