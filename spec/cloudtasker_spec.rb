# frozen_string_literal: true

RSpec.describe Cloudtasker do
  describe '::VERSION' do
    subject { Cloudtasker::VERSION }

    it { is_expected.not_to be_nil }
  end

  describe '.logger' do
    subject { described_class.logger }

    it { is_expected.to eq(described_class.config.logger) }
  end
end
