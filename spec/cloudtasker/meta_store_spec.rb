# frozen_string_literal: true

RSpec.describe Cloudtasker::MetaStore do
  describe '.new' do
    let(:hash) { { 'foo' => 'bar' } }
    let(:meta) { described_class.new(hash) }

    it { expect(meta.to_h).to eq(JSON.parse(hash.to_json, symbolize_names: true)) }
  end

  describe '#set' do
    let(:meta) { described_class.new }
    let(:key) { 'some_id' }
    let(:val) { 'foo' }

    before { meta.set(key, val) }
    it { expect(meta.to_h[key.to_sym]).to eq(val) }
  end

  describe '#get' do
    let(:meta) { described_class.new }
    let(:key) { 'some_id' }
    let(:val) { 'foo' }

    before { meta.set(key, val) }
    it { expect(meta.get(key)).to eq(val) }
  end

  describe '#del' do
    let(:meta) { described_class.new }
    let(:key) { 'some_id' }

    before { meta.set(key, 'foo') }
    before { meta.del(key) }
    it { expect(meta.to_h).not_to have_key(key.to_sym) }
  end

  describe '#to_h' do
    subject { described_class.new(hash).to_h }

    let(:hash) { { 'foo' => 'bar' } }

    it { is_expected.to eq(JSON.parse(hash.to_json, symbolize_names: true)) }
  end

  describe '#to_json' do
    subject { described_class.new(hash).to_json }

    let(:hash) { { 'foo' => 'bar' } }

    it { is_expected.to eq(hash.to_json) }
  end

  describe '#==' do
    subject { described_class.new(hash) }

    let(:hash) { { 'foo' => 'bar' } }

    context 'with identical hash' do
      it { is_expected.to eq(hash) }
    end

    context 'with identical meta' do
      it { is_expected.to eq(described_class.new(hash)) }
    end

    context 'with different object' do
      it { is_expected.not_to eq('foo') }
    end
  end
end
