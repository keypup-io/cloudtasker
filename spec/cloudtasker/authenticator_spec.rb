# frozen_string_literal: true

RSpec.describe Cloudtasker::Authenticator do
  let(:config) { Cloudtasker.config }

  describe '.verification_token' do
    subject { described_class.verification_token }

    let(:expected_token) { JWT.encode({ iat: Time.now.to_i }, config.secret, described_class::JWT_ALG) }

    around { |e| Timecop.freeze { e.run } }

    it { is_expected.to eq(expected_token) }
  end

  describe '.bearer_token' do
    subject { described_class.bearer_token }

    let(:verification_token) { '123456789' }

    before { expect(described_class).to receive(:verification_token).and_return(verification_token) }
    it { is_expected.to eq("Bearer #{verification_token}") }
  end

  describe '.verify' do
    subject { described_class.verify(token) }

    let(:token) { JWT.encode({ iat: Time.now.to_i }, secret, described_class::JWT_ALG) }

    context 'with valid token' do
      let(:secret) { config.secret }

      it { is_expected.to be_truthy }
    end

    context 'with invalid token' do
      let(:secret) { "#{config.secret}a" }

      it { is_expected.to be_falsey }
    end
  end

  describe '.verify!' do
    subject(:verify!) { described_class.verify!(token) }

    let(:token) { JWT.encode({ iat: Time.now.to_i }, secret, described_class::JWT_ALG) }

    context 'with valid token' do
      let(:secret) { config.secret }

      it { is_expected.to be_truthy }
    end

    context 'with invalid token' do
      let(:secret) { "#{config.secret}a" }

      it { expect { verify! }.to raise_error(Cloudtasker::AuthenticationError) }
    end
  end

  describe '.sign_payload' do
    subject { described_class.sign_payload(payload) }

    let(:payload) { { 'foo' => 'bar' }.to_json }

    it { is_expected.to eq(OpenSSL::HMAC.hexdigest('sha256', config.secret, payload)) }
  end

  describe '.verify_signature!' do
    subject(:verify!) { described_class.verify_signature!(signature, payload) }

    let(:payload) { { 'foo' => 'bar' }.to_json }

    context 'with valid token' do
      let(:signature) { described_class.sign_payload(payload) }

      it { is_expected.to be_truthy }
    end

    context 'with invalid token' do
      let(:signature) { 'some-invalid-signature' }

      it { expect { verify! }.to raise_error(Cloudtasker::AuthenticationError) }
    end
  end
end
