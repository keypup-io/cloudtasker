# frozen_string_literal: true

RSpec.describe Cloudtasker::Worker do
  let(:worker_class) { TestWorker }

  describe '.perform_in' do
    subject { worker_class.perform_in(delay, arg1, arg2) }

    let(:delay) { 10 }
    let(:arg1) { 1 }
    let(:arg2) { 2 }
    let(:task) { instance_double('Cloudtasker::Task') }
    let(:resp) { instance_double('Google::Cloud::Tasks::V2beta3::Task') }

    before do
      allow(Cloudtasker::Task).to receive(:new).with(worker: worker_class, args: [arg1, arg2]).and_return(task)
      allow(task).to receive(:schedule).with(interval: delay).and_return(resp)
    end

    it { is_expected.to eq(resp) }
  end

  describe '.perform_async' do
    subject { worker_class.perform_async(arg1, arg2) }

    let(:arg1) { 1 }
    let(:arg2) { 2 }
    let(:resp) { instance_double('Google::Cloud::Tasks::V2beta3::Task') }

    before { allow(worker_class).to receive(:perform_in).with(nil, arg1, arg2).and_return(resp) }
    it { is_expected.to eq(resp) }
  end

  describe '.new' do
    subject { worker_class.new(args) }

    let(:args) { [1, 2] }

    it { is_expected.to have_attributes(args: args) }
  end

  describe '#execute' do
    subject { worker.execute }

    let(:worker) { worker_class.new(args) }
    let(:args) { [1, 2] }
    let(:resp) { 'some-result' }

    before { allow(worker).to receive(:perform).with(*args).and_return(resp) }
    it { is_expected.to eq(resp) }
  end
end
