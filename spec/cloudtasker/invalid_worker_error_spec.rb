# frozen_string_literal: true

RSpec.describe Cloudtasker::InvalidWorkerError do
  describe '#initialize' do
    context 'with worker name' do
      subject { described_class.new('SomeWorker') }

      it { is_expected.to have_attributes(message: 'Invalid worker: SomeWorker') }
    end

    context 'without worker name' do
      subject { described_class.new }

      it { is_expected.to have_attributes(message: 'Invalid worker') }
    end

    context 'with nil worker name' do
      subject { described_class.new(nil) }

      it { is_expected.to have_attributes(message: 'Invalid worker') }
    end
  end
end
