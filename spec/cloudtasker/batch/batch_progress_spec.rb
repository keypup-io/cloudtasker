# frozen_string_literal: true

require 'cloudtasker/batch/middleware'

RSpec.describe Cloudtasker::Batch::BatchProgress do
  let(:batch) { instance_double(Cloudtasker::Batch::Job) }
  let(:batch_progress) { described_class.new([batch]) }

  describe '.new' do
    subject { batch_progress }

    it { is_expected.to have_attributes(batches: [batch]) }
  end

  describe '#count' do
    subject { batch_progress.count(*args) }

    let(:args) { [] }
    let(:count) { 18 }

    context 'with no args' do
      before { allow(batch).to receive(:batch_state_count).with('all').and_return(count) }
      it { is_expected.to eq(count) }
    end

    context 'with status provided' do
      let(:args) { ['processing'] }

      before { allow(batch).to receive(:batch_state_count).with(args[0]).and_return(count) }
      it { is_expected.to eq(count) }
    end
  end

  describe '#total' do
    subject { batch_progress.total }

    let(:count) { 18 }

    before { allow(batch_progress).to receive(:count).and_return(count) }
    it { is_expected.to eq(count) }
  end

  %w[scheduled processing completed errored dead].each do |tested_status|
    describe "##{tested_status}" do
      subject { batch_progress.send(tested_status) }

      let(:count) { 18 }

      before { allow(batch_progress).to receive(:count).with(tested_status).and_return(count) }
      it { is_expected.to eq(count) }
    end
  end

  describe '#pending' do
    subject { batch_progress.pending }

    let(:total) { 25 }
    let(:done) { 18 }

    before do
      allow(batch_progress).to receive_messages(total: total, done: done)
    end

    it { is_expected.to eq(total - done) }
  end

  describe '#done' do
    subject { batch_progress.done }

    let(:completed) { 25 }
    let(:dead) { 18 }

    before do
      allow(batch_progress).to receive_messages(completed: completed, dead: dead)
    end

    it { is_expected.to eq(completed + dead) }
  end

  describe '#percent' do
    subject { batch_progress.percent(**opts) }

    let(:opts) { {} }
    let(:total) { 25 }
    let(:done) { 18 }

    before do
      allow(batch_progress).to receive_messages(total: total, done: done)
    end

    context 'with batch' do
      it { is_expected.to eq((done.to_f / total) * 100) }
    end

    context 'with min_total > total' do
      let(:opts) { { min_total: 1000 } }

      it { is_expected.to eq((done.to_f / opts[:min_total]) * 100) }
    end

    context 'with min_total < total' do
      let(:opts) { { min_total: total / 2 } }

      it { is_expected.to eq((done.to_f / total) * 100) }
    end

    context 'with additive smoothing' do
      let(:opts) { { smoothing: 10 } }

      it { is_expected.to eq((done.to_f / (total + opts[:smoothing])) * 100) }
    end
  end

  describe '#+' do
    subject { batch_progress + other }

    let(:other) { described_class.new([instance_double(Cloudtasker::Batch::Job)]) }

    it { is_expected.to have_attributes(class: described_class, batches: batch_progress.batches + other.batches) }
  end
end
