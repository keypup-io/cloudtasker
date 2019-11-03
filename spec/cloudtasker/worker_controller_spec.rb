# frozen_string_literal: true

RSpec.describe Cloudtasker::WorkerController, type: :controller do
  routes { Cloudtasker::Engine.routes }

  describe 'POST #run' do
    subject { post :run, body: { worker: worker_class_name, args: args, other: 'arg' }.to_json, as: :json }

    let(:worker_class_name) { 'TestWorker' }
    let(:args) { [1, 2] }
    let(:expected_payload) { { 'worker' => worker_class_name, 'args' => args } }
    let(:auth_token) { Cloudtasker::Authenticator.verification_token }

    context 'with valid worker' do
      before do
        request.env['HTTP_AUTHORIZATION'] = "Bearer #{auth_token}"
        allow(Cloudtasker::Task).to receive(:execute_from_payload!)
          .with(expected_payload)
          .and_return(true)
      end
      after { expect(Cloudtasker::Task).to have_received(:execute_from_payload!) }
      it { is_expected.to be_successful }
    end

    context 'with valid worker and execution errors' do
      before do
        request.env['HTTP_AUTHORIZATION'] = "Bearer #{auth_token}"
        allow(Cloudtasker::Task).to receive(:execute_from_payload!)
          .with(expected_payload)
          .and_raise(ArgumentError)
      end
      it { is_expected.to have_http_status(:unprocessable_entity) }
    end

    context 'with invalid worker' do
      before do
        request.env['HTTP_AUTHORIZATION'] = "Bearer #{auth_token}"
        allow(Cloudtasker::Task).to receive(:execute_from_payload!)
          .with(expected_payload)
          .and_raise(Cloudtasker::InvalidWorkerError)
      end
      it { is_expected.to have_http_status(:not_found) }
    end

    context 'with no authentication' do
      it { is_expected.to have_http_status(:unauthorized) }
    end

    context 'with invalid authentication' do
      before { request.env['HTTP_AUTHORIZATION'] = "Bearer #{auth_token}aaa" }
      it { is_expected.to have_http_status(:unauthorized) }
    end
  end
end
