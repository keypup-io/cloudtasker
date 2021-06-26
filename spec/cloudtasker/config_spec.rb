# frozen_string_literal: true

RSpec.describe Cloudtasker::Config do
  let(:secret) { 'some-secret' }
  let(:gcp_location_id) { 'some-location' }
  let(:gcp_project_id) { 'some-project-id' }
  let(:gcp_queue_prefix) { 'some-queue' }
  let(:processor_host) { 'http://localhost' }
  let(:processor_path) { nil }
  let(:logger) { Logger.new(nil) }
  let(:mode) { :production }
  let(:max_retries) { 10 }
  let(:store_payloads_in_redis) { 10 }
  let(:dispatch_deadline) { 15 * 60 }
  let(:on_error) { ->(e, w) {} }
  let(:on_dead) { ->(e, w) {} }

  let(:rails_hosts) { [] }
  let(:rails_secret) { 'rails_secret' }
  let(:rails_credentials) { { secret_key_base: rails_secret } }
  let(:rails_config) do
    if Rails.application.config.respond_to?(:hosts)
      instance_double('Rails::Application::Configuration', hosts: rails_hosts)
    else
      instance_double('Rails::Application::Configuration')
    end
  end
  let(:rails_app) { instance_double('Dummy::Application', credentials: rails_credentials, config: rails_config) }
  let(:rails_logger) { instance_double('ActiveSupport::Logger') }
  let(:rails_klass) { class_double('Rails', application: rails_app, logger: rails_logger) }

  let(:config) do
    Cloudtasker.configure do |c|
      c.mode = mode
      c.logger = logger
      c.secret = secret
      c.gcp_location_id = gcp_location_id
      c.gcp_project_id = gcp_project_id
      c.gcp_queue_prefix = gcp_queue_prefix
      c.processor_host = processor_host
      c.processor_path = processor_path
      c.max_retries = max_retries
      c.store_payloads_in_redis = store_payloads_in_redis
      c.dispatch_deadline = dispatch_deadline
      c.on_error = on_error
      c.on_dead = on_dead
    end

    Cloudtasker.config
  end

  describe 'redis_payload_storage_threshold' do
    subject { config.redis_payload_storage_threshold }

    context 'with integer value' do
      it { is_expected.to eq(store_payloads_in_redis) }
    end

    context 'with string value' do
      let(:store_payloads_in_redis) { '20' }

      it { is_expected.to eq(store_payloads_in_redis.to_i) }
    end

    context 'with true value' do
      let(:store_payloads_in_redis) { true }

      it { is_expected.to eq(0) }
    end

    context 'with false value' do
      let(:store_payloads_in_redis) { false }

      it { is_expected.to be_nil }
    end

    context 'with nil value' do
      let(:store_payloads_in_redis) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe '#max_retries' do
    subject { config.max_retries }

    context 'with value specified via config' do
      it { is_expected.to eq(max_retries) }
    end

    context 'with no value' do
      let(:max_retries) { nil }

      it { is_expected.to eq(described_class::DEFAULT_MAX_RETRY_ATTEMPTS) }
    end
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

    context 'with no logger provided' do
      let(:logger) { nil }

      it { is_expected.to be_a(::Logger) }
    end

    context 'with logger provided' do
      it { is_expected.to eq(logger) }
    end

    context 'with Rails and no logger provided' do
      let(:logger) { nil }

      before { stub_const('Rails', rails_klass) }
      it { is_expected.to eq(rails_logger) }
    end
  end

  describe '#secret' do
    subject(:method) { config.secret }

    context 'with value specified via config' do
      it { is_expected.to eq(secret) }
    end

    context 'with Rails secret available' do
      let(:secret) { nil }

      before { stub_const('Rails', rails_klass) }
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

  describe '#gcp_queue_prefix' do
    subject(:method) { config.gcp_queue_prefix }

    context 'with value specified via config' do
      it { is_expected.to eq(gcp_queue_prefix) }
    end

    context 'with no value' do
      let(:gcp_queue_prefix) { nil }

      it { expect { method }.to raise_error(StandardError, described_class::QUEUE_PREFIX_MISSING_ERROR) }
    end
  end

  describe '#dispatch_deadline' do
    subject { config.dispatch_deadline }

    context 'with value specified via config' do
      it { is_expected.to eq(dispatch_deadline) }
    end

    context 'with no value' do
      let(:dispatch_deadline) { nil }

      it { is_expected.to eq(described_class::DEFAULT_DISPATCH_DEADLINE) }
    end
  end

  describe '#processor_host' do
    subject(:method) { config.processor_host }

    if Rails.application.config.respond_to?(:hosts)
      context 'with rails hosts' do
        subject { rails_klass.application.config.hosts }

        let(:rails_hosts) { ['.local'] }
        let(:expected_host) { 'localhost' }

        before { stub_const('Rails', rails_klass) }
        before { config }
        it { is_expected.to include(expected_host) }
      end

      context 'with empty rails hosts' do
        subject { rails_klass.application.config.hosts }

        let(:expected_host) { 'localhost' }

        before { stub_const('Rails', rails_klass) }
        before { config }
        it { is_expected.to be_empty }
      end
    end

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

  # Error hooks
  %i[on_error on_dead].each do |hook|
    describe "##{hook}" do
      subject { config.send(hook) }

      context 'with value specified via config' do
        let(hook.to_sym) { ->(e, w) {} }

        it { is_expected.to eq(send(hook)) }
      end

      context 'with no value' do
        let(hook.to_sym) { nil }

        it { is_expected.to eq(described_class::DEFAULT_ON_ERROR) }
      end
    end
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
