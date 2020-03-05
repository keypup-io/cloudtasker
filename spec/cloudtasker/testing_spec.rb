# frozen_string_literal: true

RSpec.describe Cloudtasker::Testing do
  before { Cloudtasker::Backend::MemoryTask.clear }
  before { TestWorker.has_run = false }
  after { described_class.enable! }

  describe '.fake!' do
    subject { Cloudtasker::Backend::MemoryTask.all }

    context 'with option set' do
      before { described_class.fake! }
      before { TestWorker.perform_async(1, 2) }
      it { is_expected.to match([be_a(Cloudtasker::Backend::MemoryTask)]) }
    end

    context 'with block' do
      around do |e|
        described_class.fake! { e.run }
        expect(described_class).to be_enabled
      end
      before { TestWorker.perform_async(1, 2) }
      it { is_expected.to match([be_a(Cloudtasker::Backend::MemoryTask)]) }
    end
  end

  describe '.inline!' do
    subject { Cloudtasker::Backend::MemoryTask.all }

    context 'with option set' do
      before { described_class.inline! }
      before { TestWorker.perform_async(1, 2) }
      after { expect(TestWorker).to have_run }
      it { is_expected.to eq([]) }
    end

    context 'with block' do
      around do |e|
        described_class.inline! { e.run }
        expect(described_class).to be_enabled
      end
      before { TestWorker.perform_async(1, 2) }
      after { expect(TestWorker).to have_run }
      it { is_expected.to eq([]) }
    end
  end

  describe 'job draining' do
    before { described_class.fake! }
    before { TestWorker.perform_async(1, 2) }
    before { TestWorker.drain }
    it { expect(TestWorker).to have_run }
  end
end
