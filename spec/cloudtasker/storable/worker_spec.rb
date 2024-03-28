# frozen_string_literal: true

RSpec.describe Cloudtasker::Storable::Worker do
  let(:worker_class) { TestStorableWorker }

  describe '.store_cache_key' do
    subject { worker_class.store_cache_key(namespace) }

    let(:namespace) { :some_key }

    it { is_expected.to eq(worker_class.cache_key([Cloudtasker::Config::WORKER_STORE_PREFIX, namespace])) }
  end

  describe '.push_to_store' do
    subject { worker_class.push_to_store(namespace, *args) }

    let(:namespace) { 'some-namespace' }
    let(:args) { [1, 'two', { three: true }] }
    let(:store_cache_key) { worker_class.store_cache_key(namespace) }

    after { expect(worker_class.redis.lrange(store_cache_key, 0, -1)).to eq([args.to_json]) }
    it { is_expected.to eq(1) }
  end

  describe '.push_many_to_store' do
    subject { worker_class.push_many_to_store(namespace, args_list) }

    let(:namespace) { 'some-namespace' }
    let(:args_list) { [[2, 'four'], [1, 'two', { three: true }]] }
    let(:store_cache_key) { worker_class.store_cache_key(namespace) }

    after { expect(worker_class.redis.lrange(store_cache_key, 0, -1)).to eq(args_list.map(&:to_json)) }
    it { is_expected.to eq(args_list.size) }
  end

  describe '.pull_all_from_store' do
    subject { worker_class.pull_all_from_store(namespace, page_size: page_size) }

    let(:namespace) { 'some-namespace' }
    let(:page_size) { 5 }
    let(:results) { [] }
    let(:arg_list) { Array.new((page_size * 2) + 1) { |n| [n] } }
    let(:store_cache_key) { worker_class.store_cache_key(namespace) }

    before { worker_class.push_many_to_store(namespace, arg_list) }
    after { expect(worker_class.redis.lrange(store_cache_key, 0, -1)).to be_empty }

    context 'with no block' do
      before { allow(worker_class).to receive(:perform_async) { |*args| results << args } }
      after { expect(results.sort).to eq(arg_list.sort) }
      it { is_expected.to be_nil }
    end

    context 'with block' do
      subject do
        worker_class.pull_all_from_store(namespace, page_size: page_size) do |args|
          results << args
        end
      end

      before { expect(worker_class).not_to receive(:perform_async) }
      after { expect(results.sort).to eq(arg_list.sort) }
      it { is_expected.to be_nil }
    end
  end
end
