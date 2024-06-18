# frozen_string_literal: true

RSpec.shared_examples 'a log appender' do |level|
  subject(:log_action) { logger.send(level, msg, &block) }

  let(:msg) { 'Some message' }
  let(:block) { nil }
  let(:log_msg) { logger.formatted_message(msg) }
  let(:log_block) { logger.log_block }

  context 'without block' do
    before do
      allow(Cloudtasker.logger).to receive(level) do |args, &arg_block|
        expect(args).to eq(log_msg)
        expect(arg_block.call).to eq(log_block.call)
      end
    end
    after { expect(Cloudtasker.logger).to have_received(level) }
    it { is_expected.to be_truthy }
  end

  context 'with block' do
    let(:block) { proc { { foo: 'bar' } } }

    before do
      allow(Cloudtasker.logger).to receive(level) do |args, &arg_block|
        expect(args).to eq(log_msg)
        expect(arg_block.call).to eq(log_block.call.merge(block.call))
      end
    end
    after { expect(Cloudtasker.logger).to have_received(level) }
    it { is_expected.to be_truthy }
  end

  if defined?(Rails)
    context 'with ActiveSupport::Logger' do
      let(:as_logger) { ActiveSupport::Logger.new(nil) }

      before do
        allow(logger).to receive(:logger).and_return(as_logger)
        allow(as_logger).to receive(level) do |*_args, &block|
          expect(block.call).to eq("#{log_msg} -- #{log_block.call}")
        end
      end
      after { expect(as_logger).to have_received(level) }
      it { is_expected.to be_truthy }
    end
  end

  describe 'end to end' do
    let(:block) { proc { { foo: 'bar' } } }

    before { allow(logger).to receive(:logger).and_return(logger_adapter) }

    context 'with Logger' do
      let(:logger_adapter) { Logger.new(nil) }

      it { expect { log_action }.not_to raise_error }
    end

    if defined?(Rails)
      context 'with ActiveSupport::Logger' do
        let(:logger_adapter) { ActiveSupport::Logger.new(nil) }

        it { expect { log_action }.not_to raise_error }
      end
    end

    context 'with SemanticLogger' do
      let(:logger_adapter) { SemanticLogger[Cloudtasker] }
      let(:block) { -> { { foo: 'bar' } } }

      it { expect { log_action }.not_to raise_error }
    end
  end
end

RSpec.describe Cloudtasker::WorkerLogger do
  let(:logger) { described_class.new(worker) }
  let(:worker) { TestWorker.new(job_args: [1, 2]) }

  describe '.new' do
    subject { logger }

    it { is_expected.to have_attributes(worker: worker) }
  end

  describe '.truncate' do
    subject { described_class.truncate(payload, **config) }

    let(:payload) do
      [
        { string: 'a' * 100 },
        { parent: {
          array: [1] * 20,
          child: {
            subchild: { my: { sub: 'attribute' } }
          }
        } }
      ]
    end

    context 'with no options specified' do
      let(:config) { {} }
      let(:expected) do
        [{ string: "#{'a' * 61}..." },
         { parent: { array: ([1] * 10) + ['...10 items...'], child: { subchild: '{hash}' } } }]
      end

      it { is_expected.to eq(expected) }
    end

    context 'with options specified' do
      let(:config) { { string_limit: 10, array_limit: 2, max_depth: 4 } }
      let(:expected) do
        [{ string: 'aaaaaaa...' },
         { parent: { array: [1, 1, '...18 items...'], child: { subchild: { my: '{hash}' } } } }]
      end

      it { is_expected.to eq(expected) }
    end

    context 'with all options disabled' do
      let(:config) { { string_limit: -1, array_limit: -1, max_depth: -1 } }

      it { is_expected.to eq(payload) }
    end
  end

  describe '#context_processor' do
    subject { logger.context_processor }

    let(:processor) { lambda(&:to_h) }

    context 'with no context_processor defined' do
      it { is_expected.to eq(described_class::DEFAULT_CONTEXT_PROCESSOR) }
    end

    context 'with globally defined context_processor' do
      before { allow(described_class).to receive(:log_context_processor).and_return(processor) }
      it { is_expected.to eq(processor) }
    end

    context 'with locally defined context_processor' do
      let(:options) { { log_context_processor: processor } }

      before { allow(worker.class).to receive(:cloudtasker_options_hash).and_return(options) }
      it { is_expected.to eq(processor) }
    end
  end

  describe '#log_block' do
    subject { logger.log_block.call }

    it { is_expected.to eq(logger.context_processor.call(worker)) }
  end

  describe '#logger' do
    subject { logger.logger }

    it { is_expected.to eq(Cloudtasker.logger) }
  end

  describe '#formatted_message_as_string' do
    subject { logger.formatted_message_as_string(msg) }

    let(:msg_content) { msg }
    let(:expected_msg) { "[Cloudtasker][#{worker.class}][#{worker.job_id}] #{msg_content}" }

    context 'with error' do
      let(:msg) { StandardError.new('some error').tap { |k| k.set_backtrace(%w[line1 line2 line3]) } }
      let(:msg_content) { [msg.inspect, msg.backtrace].flatten(1).join("\n") }

      it { is_expected.to eq(expected_msg) }
    end

    context 'with string' do
      let(:msg) { 'some message' }

      it { is_expected.to eq(expected_msg) }
    end

    context 'with object' do
      let(:msg) { { foo: 'bar' } }
      let(:msg_content) { msg.inspect }

      it { is_expected.to eq(expected_msg) }
    end
  end

  describe '#formatted_message' do
    subject { logger.formatted_message(msg) }

    context 'with error' do
      let(:msg) { StandardError.new('some error') }

      it { is_expected.to eq(msg) }
    end

    context 'with string' do
      let(:msg) { 'some message' }

      it { is_expected.to eq(logger.formatted_message_as_string(msg)) }
    end

    context 'with object' do
      let(:msg) { { foo: 'bar' } }

      it { is_expected.to eq(msg) }
    end
  end

  describe '#info' do
    it_behaves_like 'a log appender', :info
  end

  describe '#error' do
    it_behaves_like 'a log appender', :error
  end

  describe '#fatal' do
    it_behaves_like 'a log appender', :fatal
  end

  describe '#debug' do
    it_behaves_like 'a log appender', :debug
  end

  describe 'other method' do
    subject { logger.info? }

    before { allow(Cloudtasker.logger).to receive(:info?).and_return(true) }
    after { expect(Cloudtasker.logger).to have_received(:info?) }
    it { is_expected.to be_truthy }
  end
end
