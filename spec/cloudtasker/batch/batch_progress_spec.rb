# frozen_string_literal: true

require 'cloudtasker/batch/middleware'

RSpec.describe Cloudtasker::Batch::BatchProgress do
  let(:batch_state) do
    {
      '1' => 'completed',
      '2' => 'scheduled',
      '3' => 'processing',
      '4' => 'errored',
      '5' => 'dead'
    }
  end
  let(:batch_progress) { described_class.new(batch_state) }

  describe '.new' do
    subject { batch_progress }

    it { is_expected.to have_attributes(batch_state: batch_state) }
  end

  describe '#total' do
    subject { batch_progress.total }

    it { is_expected.to eq(batch_state.keys.count) }
  end

  describe '#completed' do
    subject { batch_progress.completed }

    it { is_expected.to eq(batch_state.values.count { |e| e == 'completed' }) }
  end

  describe '#scheduled' do
    subject { batch_progress.scheduled }

    it { is_expected.to eq(batch_state.values.count { |e| e == 'scheduled' }) }
  end

  describe '#errored' do
    subject { batch_progress.errored }

    it { is_expected.to eq(batch_state.values.count { |e| e == 'errored' }) }
  end

  describe '#dead' do
    subject { batch_progress.dead }

    it { is_expected.to eq(batch_state.values.count { |e| e == 'dead' }) }
  end

  describe '#processing' do
    subject { batch_progress.processing }

    it { is_expected.to eq(batch_state.values.count { |e| e == 'processing' }) }
  end

  describe '#pending' do
    subject { batch_progress.pending }

    it { is_expected.to eq(batch_state.values.count { |e| %w[dead completed].exclude?(e) }) }
  end

  describe '#done' do
    subject { batch_progress.done }

    it { is_expected.to eq(batch_state.values.count { |e| %w[dead completed].include?(e) }) }
  end

  describe '#percent' do
    subject { batch_progress.percent }

    context 'with batch' do
      it { is_expected.to eq(batch_progress.done.to_f / batch_progress.total) }
    end

    context 'with empty elements' do
      let(:batch_state) { {} }

      it { is_expected.to be_zero }
    end
  end

  describe '#+' do
    subject { batch_progress + other }

    let(:other_state) do
      {
        '4' => 'completed',
        '5' => 'scheduled',
        '6' => 'processing'
      }
    end
    let(:other) { described_class.new(other_state) }

    it { is_expected.to be_a(described_class) }
    it { is_expected.to have_attributes(batch_state: batch_state.merge(other_state)) }
  end
end
