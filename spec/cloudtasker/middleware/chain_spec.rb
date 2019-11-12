# frozen_string_literal: true

RSpec.describe Cloudtasker::Middleware::Chain do
  let(:chain) { described_class.new }

  describe '#each' do
    let(:expected) do
      [
        have_attributes(klass: TestMiddleware),
        have_attributes(klass: TestMiddleware2)
      ]
    end

    before do
      chain.add(TestMiddleware)
      chain.add(TestMiddleware2)
    end

    it { expect { |b| chain.each(&b) }.to yield_successive_args(*expected) }
  end

  describe '#entries' do
    before do
      chain.add(TestMiddleware)
      chain.add(TestMiddleware2)
    end

    it { expect(chain.entries[0]).to have_attributes(klass: TestMiddleware) }
    it { expect(chain.entries[1]).to have_attributes(klass: TestMiddleware2) }
  end

  describe '#remove' do
    subject { chain.entries }

    before do
      chain.add(TestMiddleware)
      chain.remove(TestMiddleware)
    end

    it { is_expected.to be_empty }
  end

  describe '#add' do
    before { chain.add(TestMiddleware, 'foo') }

    it { expect(chain.entries[0]).to have_attributes(klass: TestMiddleware, args: ['foo']) }
  end

  describe '#prepend' do
    before do
      chain.add(TestMiddleware)
      chain.prepend(TestMiddleware2)
    end

    it { expect(chain.entries[0]).to have_attributes(klass: TestMiddleware2) }
    it { expect(chain.entries[1]).to have_attributes(klass: TestMiddleware) }
  end

  describe '#insert_before' do
    before do
      chain.add(TestMiddleware)
      chain.add(TestMiddleware2)
      chain.insert_before(TestMiddleware2, TestMiddleware3)
    end

    it { expect(chain.entries[0]).to have_attributes(klass: TestMiddleware) }
    it { expect(chain.entries[1]).to have_attributes(klass: TestMiddleware3) }
    it { expect(chain.entries[2]).to have_attributes(klass: TestMiddleware2) }
  end

  describe '#insert_after' do
    before do
      chain.add(TestMiddleware)
      chain.add(TestMiddleware2)
      chain.insert_after(TestMiddleware, TestMiddleware3)
    end

    it { expect(chain.entries[0]).to have_attributes(klass: TestMiddleware) }
    it { expect(chain.entries[1]).to have_attributes(klass: TestMiddleware3) }
    it { expect(chain.entries[2]).to have_attributes(klass: TestMiddleware2) }
  end

  describe '#exists?' do
    subject { chain.exists?(TestMiddleware) }

    context 'with middleware present' do
      before { chain.add(TestMiddleware) }
      it { is_expected.to be_truthy }
    end

    context 'with middleware absent' do
      before { chain.add(TestMiddleware2) }
      it { is_expected.to be_falsey }
    end
  end

  describe '#empty?' do
    subject { chain.empty? }

    context 'with no middlewares' do
      it { is_expected.to be_truthy }
    end

    context 'with middlewares' do
      before { chain.add(TestMiddleware) }
      it { is_expected.to be_falsey }
    end
  end

  describe '#retrieve' do
    subject(:retrieve) { chain.retrieve }

    before do
      chain.add(TestMiddleware, 'foo')
      chain.add(TestMiddleware2)
    end

    it { expect(retrieve[0]).to be_a(TestMiddleware) }
    it { expect(retrieve[0]).to have_attributes(arg: 'foo') }
    it { expect(retrieve[1]).to be_a(TestMiddleware2) }
  end

  describe '#clear' do
    before do
      chain.add(TestMiddleware)
      chain.clear
    end

    it { is_expected.to be_empty }
  end

  describe '#invoke' do
    let(:worker) { TestWorker.new(job_id: '1') }

    context 'without chain' do
      it { expect { |b| chain.invoke(&b) }.to yield_control }
    end

    context 'with chain' do
      let(:middleware) { TestMiddleware.new }

      before { allow(chain).to receive(:retrieve).and_return([middleware]) }
      before { allow(chain).to receive(:empty?).and_return(false) }
      after { expect(middleware.called).to be_truthy }
      it { expect { |b| chain.invoke(worker, &b) }.to yield_control }
    end
  end
end
