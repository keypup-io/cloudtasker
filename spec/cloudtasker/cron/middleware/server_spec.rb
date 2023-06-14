# frozen_string_literal: true

require 'cloudtasker/cron/middleware'

RSpec.describe Cloudtasker::Cron::Middleware::Server do
  let(:middleware) { described_class.new }

  describe '#call' do
    let(:worker) { instance_double(Cloudtasker::Worker) }
    let(:job) { instance_double(Cloudtasker::Cron::Job) }

    before { allow(Cloudtasker::Cron::Job).to receive(:new).with(worker).and_return(job) }
    before { allow(job).to receive(:execute).and_yield }
    it { expect { |b| middleware.call(worker, &b) }.to yield_control }
  end
end
