# frozen_string_literal: true

RSpec.describe Cloudtasker::Config do
  let(:secret) { 'some-secret' }
  let(:gcp_location_id) { 'some-location' }
  let(:gcp_project_id) { 'some-project-id' }
  let(:gcp_queue_id) { 'some-queue-id' }
  let(:processor_host) { 'http://localhost' }
  let(:processor_path) { nil }

  let(:config) do
    Cloudtasker.configure do |c|
      c.secret = secret
      c.gcp_location_id = gcp_location_id
      c.gcp_project_id = gcp_project_id
      c.gcp_queue_id = gcp_queue_id
      c.processor_host = processor_host
      c.processor_path = processor_path
    end

    Cloudtasker.config
  end

  describe '#secret' do
    subject(:method) { config.secret }

    context 'with value specified via config' do
      it { is_expected.to eq(secret) }
    end

    context 'with Rails secret available' do
      let(:secret) { nil }
      let(:rails_secret) { 'rails_secret' }
      let(:rails_app) { instance_double('application') }
      let(:credentials) { instance_double('credentials') }

      before { allow(Rails).to receive(:application).and_return(rails_app) }
      before { allow(rails_app).to receive(:credentials).and_return(credentials) }
      before { allow(credentials).to receive(:secret_key_base).and_return(rails_secret) }
      it { is_expected.to eq(rails_secret) }
    end

    context 'with no value' do
      let(:secret) { nil }

      before { Object.send(:remove_const, :Rails) }
      it { expect { method }.to raise_error(StandardError, described_class::SECRET_MISSING_ERROR) }
    end
  end

  describe '#gcp_location_id' do
    subject { config.gcp_location_id }

    context 'with value specified via config' do
      it { is_expected.to eq(gcp_location_id) }
    end

    context 'with no value' do
      let(:gcp_location_id) { nil }

      it { is_expected.to eq(described_class::DEFAULT_LOCATION_ID) }
    end
  end

  describe '#gcp_project_id' do
    subject(:method) { config.gcp_project_id }

    context 'with value specified via config' do
      it { is_expected.to eq(gcp_project_id) }
    end

    context 'with no value' do
      let(:gcp_project_id) { nil }

      it { expect { method }.to raise_error(StandardError, described_class::PROJECT_ID_MISSING_ERROR) }
    end
  end

  describe '#gcp_queue_id' do
    subject(:method) { config.gcp_queue_id }

    context 'with value specified via config' do
      it { is_expected.to eq(gcp_queue_id) }
    end

    context 'with no value' do
      let(:gcp_queue_id) { nil }

      it { expect { method }.to raise_error(StandardError, described_class::QUEUE_ID_MISSING_ERROR) }
    end
  end

  describe '#processor_host' do
    subject(:method) { config.processor_host }

    context 'with value specified via config' do
      it { is_expected.to eq(processor_host) }
    end

    context 'with no value' do
      let(:processor_host) { nil }

      it { expect { method }.to raise_error(StandardError, described_class::PROCESSOR_HOST_MISSING) }
    end
  end

  describe '#processor_path' do
    subject { config.processor_path }

    context 'with value specified via config' do
      let(:processor_path) { '/foo' }

      it { is_expected.to eq(processor_path) }
    end

    context 'with no value' do
      let(:processor_path) { nil }

      it { is_expected.to eq(described_class::DEFAULT_PROCESSOR_PATH) }
    end
  end

  describe '#processor_url' do
    subject { config.processor_url }

    it { is_expected.to eq("#{config.processor_host}#{config.processor_path}") }
  end
end
