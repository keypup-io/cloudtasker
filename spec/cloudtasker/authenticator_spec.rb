# frozen_string_literal: true

RSpec.describe Cloudtasker::Authenticator do
  let(:config) { Cloudtasker.config }

  describe '.verification_token' do
    subject { described_class.verification_token }

    let(:expected_token) { JWT.encode({ iat: Time.now.to_i }, config.secret, described_class::JWT_ALG) }

    around { |e| Timecop.freeze { e.run } }

    it { is_expected.to eq(expected_token) }
  end

  describe '.verify' do
    subject { described_class.verify(token) }

    let(:token) { JWT.encode({ iat: Time.now.to_i }, secret, described_class::JWT_ALG) }

    context 'with valid token' do
      let(:secret) { config.secret }

      it { is_expected.to be_truthy }
    end

    context 'with invalid token' do
      let(:secret) { config.secret + 'a' }

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
      let(:secret) { config.secret + 'a' }

      it { expect { verify! }.to raise_error(Cloudtasker::AuthenticationError) }
    end
  end
end
