# frozen_string_literal: true

require 'cloudtasker/redis_client'

RSpec.describe Cloudtasker::RedisClient do
  let(:redis_client) { described_class.new }

  describe '.client' do
    subject { described_class.client }

    it { is_expected.to be_a(Redis) }
    it { is_expected.to have_attributes(id: Cloudtasker.config.redis[:url]) }
  end

  describe '#client' do
    subject { redis_client.client }

    it { is_expected.to eq(described_class.client) }
  end

  describe '#fetch' do
    subject { redis_client.fetch(key) }

    let(:key) { 'foo' }
    let(:content) { { 'foo' => 'bar' } }

    before { redis_client.set(key, content.to_json) }
    it { is_expected.to eq(JSON.parse(content.to_json, symbolize_names: true)) }
  end

  describe '#write' do
    subject { redis_client.fetch(key) }

    let(:key) { 'foo' }
    let(:content) { { 'foo' => 'bar' } }

    before { redis_client.write(key, content) }
    it { is_expected.to eq(JSON.parse(content.to_json, symbolize_names: true)) }
  end

  describe '#clear' do
    subject { redis_client.keys }

    before do
      redis_client.set('foo', 'bar')
      redis_client.clear
    end

    it { is_expected.to be_empty }
  end

  describe '#with_lock' do
    let(:key) { 'cache-key' }
    let(:lock_key) { 'cloudtasker/lock/cache-key' }

    before { allow(redis_client.client).to receive(:setnx).with(lock_key, true).and_return(true) }
    after { expect(redis_client.client).to have_received(:setnx) }
    it { expect { |b| redis_client.with_lock(key, &b) }.to yield_control }
  end

  describe '#search' do
    subject { redis_client.search(pattern).sort }

    let(:keys) { 50.times.map { |n| "foo/#{n}" }.sort }

    before { keys.each { |e| redis_client.set(e, true) } }

    context 'with keys matching pattern' do
      let(:pattern) { 'foo/*' }

      it { is_expected.to eq(keys) }
    end

    context 'with no keys matching' do
      let(:pattern) { 'bar/*' }

      it { is_expected.to be_empty }
    end
  end

  describe '#get' do
    subject { redis_client.get(key) }

    let(:key) { 'foo' }
    let(:content) { 'bar' }

    before { redis_client.set(key, content) }
    it { is_expected.to eq(content) }
  end
end
