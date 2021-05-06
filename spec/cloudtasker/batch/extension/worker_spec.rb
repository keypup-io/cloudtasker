# frozen_string_literal: true

require 'cloudtasker/batch/middleware'

RSpec.describe Cloudtasker::Batch::Extension::Worker do
  describe '#batch' do
    subject { worker.batch }

    let(:worker) { TestWorker.new }

    before { worker.batch = Cloudtasker::Batch::Job.new(worker) }
    it { is_expected.to be_a(Cloudtasker::Batch::Job) }
    it { is_expected.to have_attributes(worker: worker) }
  end

  describe '#parent_batch' do
    subject { worker.parent_batch }

    let(:worker) { TestWorker.new }

    before { worker.parent_batch = Cloudtasker::Batch::Job.new(worker) }
    it { is_expected.to be_a(Cloudtasker::Batch::Job) }
    it { is_expected.to have_attributes(worker: worker) }
  end
end
