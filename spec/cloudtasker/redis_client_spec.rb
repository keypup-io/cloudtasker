# frozen_string_literal: true

require 'cloudtasker/redis_client'

RSpec.describe Cloudtasker::RedisClient do
  describe '#client' do
    subject { described_class.client }

    it { is_expected.to be_a(Redis) }
    it { is_expected.to have_attributes(id: Cloudtasker.config.redis[:url]) }
  end

  describe '#fetch' do
    subject { described_class.fetch(key) }

    let(:key) { 'foo' }
    let(:content) { { 'foo' => 'bar' } }

    before { described_class.set(key, content.to_json) }
    it { is_expected.to eq(JSON.parse(content.to_json, symbolize_names: true)) }
  end

  describe '#write' do
    subject { described_class.fetch(key) }

    let(:key) { 'foo' }
    let(:content) { { 'foo' => 'bar' } }

    before { described_class.write(key, content) }
    it { is_expected.to eq(JSON.parse(content.to_json, symbolize_names: true)) }
  end

  describe '#clear' do
    subject { described_class.keys }

    before do
      described_class.set('foo', 'bar')
      described_class.clear
    end

    it { is_expected.to be_empty }
  end

  describe '#with_lock' do
    let(:key) { 'cache-key' }
    let(:lock_key) { 'cache-key/lock' }

    before { allow(described_class.client).to receive(:setnx).with(lock_key, true).and_return(true) }
    after { expect(described_class.client).to have_received(:setnx) }
    it { expect { |b| described_class.with_lock(key, &b) }.to yield_control }
  end

  describe '#get' do
    subject { described_class.get(key) }

    let(:key) { 'foo' }
    let(:content) { 'bar' }

    before { described_class.set(key, content) }
    it { is_expected.to eq(content) }
  end
end
