# frozen_string_literal: true

RSpec.describe Cloudtasker::Config do
  let(:secret) { 'some-secret' }
  let(:gcp_location_id) { 'some-location' }
  let(:gcp_project_id) { 'some-project-id' }
  let(:gcp_queue_id) { 'some-queue-id' }
  let(:processor_host) { 'http://localhost' }
  let(:processor_path) { nil }
  let(:logger) { Logger.new(nil) }
  let(:mode) { :production }

  let(:config) do
    Cloudtasker.configure do |c|
      c.mode = mode
      c.logger = logger
      c.secret = secret
      c.gcp_location_id = gcp_location_id
      c.gcp_project_id = gcp_project_id
      c.gcp_queue_id = gcp_queue_id
      c.processor_host = processor_host
      c.processor_path = processor_path
    end

    Cloudtasker.config
  end

  describe '#mode' do
    subject { config.mode }

    context 'with mode specified' do
      it { is_expected.to eq(mode) }
    end

    context 'with no mode and development environment' do
      let(:mode) { nil }

      before { allow(config).to receive(:environment).and_return('development') }
      it { is_expected.to eq(:development) }
    end

    context 'with no mode and other environment' do
      let(:mode) { nil }

      before { allow(config).to receive(:environment).and_return('production') }
      it { is_expected.to eq(:production) }
    end
  end

  describe '#environment' do
    subject { config.environment }

    before { allow(ENV).to receive(:[]).with('CLOUDTASKER_ENV').and_return(nil) }
    before { allow(ENV).to receive(:[]).with('RAILS_ENV').and_return(nil) }
    before { allow(ENV).to receive(:[]).with('RACK_ENV').and_return(nil) }

    context 'with no env-related vars' do
      it { is_expected.to eq('development') }
    end

    context 'with CLOUDTASKER_ENV' do
      before { allow(ENV).to receive(:[]).with('CLOUDTASKER_ENV').and_return('production') }
      it { is_expected.to eq('production') }
    end

    context 'with RACK_ENV' do
      before { allow(ENV).to receive(:[]).with('RACK_ENV').and_return('production') }
      it { is_expected.to eq('production') }
    end

    context 'with RAILS_ENV' do
      before { allow(ENV).to receive(:[]).with('RAILS_ENV').and_return('production') }
      it { is_expected.to eq('production') }
    end
  end

  describe '#logger' do
    subject { config.logger }

    context 'with no logger provider' do
      let(:logger) { nil }

      it { is_expected.to be_a(::Logger) }
    end

    context 'with logger provider' do
      it { is_expected.to eq(logger) }
    end
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

      before { stub_const('Rails', Class.new) }
      before { allow(Rails).to receive(:application).and_return(rails_app) }
      before { allow(rails_app).to receive(:credentials).and_return(credentials) }
      before { allow(credentials).to receive(:secret_key_base).and_return(rails_secret) }
      it { is_expected.to eq(rails_secret) }
    end

    context 'with no value' do
      let(:secret) { nil }

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

  describe '#client_middleware' do
    subject(:middlewares) { config.client_middleware }

    before do
      config.client_middleware do |chain|
        chain.add(TestMiddleware)
      end
    end

    it { is_expected.to be_a(Cloudtasker::Middleware::Chain) }
    it { expect(middlewares).to be_exists(TestMiddleware) }
  end

  describe '#server_middleware' do
    subject(:middlewares) { config.server_middleware }

    before do
      config.server_middleware do |chain|
        chain.add(TestMiddleware)
      end
    end

    it { is_expected.to be_a(Cloudtasker::Middleware::Chain) }
    it { expect(middlewares).to be_exists(TestMiddleware) }
  end
end
