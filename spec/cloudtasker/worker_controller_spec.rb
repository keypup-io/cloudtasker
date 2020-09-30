# frozen_string_literal: true

require 'rack/test'

RSpec.describe Cloudtasker::WorkerController do
  include Rack::Test::Methods

  let(:app) { described_class.new }

  describe 'POST /cloudtasker/run' do
    let(:payload) do
      {
        'worker' => worker_class_name,
        'job_id' => id,
        'job_args' => args,
        'job_meta' => meta,
        'job_queue' => queue,
        'other' => 'foo'
      }
    end

    let(:mime_type) { :json }
    let(:request_body) { payload.to_json }
    let(:expected_payload) { payload.merge(job_retries: retries, task_id: task_id) }
    let(:task_id) { 'ab2341f' }
    let(:id) { '111' }
    let(:worker_class_name) { 'TestWorker' }
    let(:args) { [1, 2] }
    let(:meta) { { 'foo' => 'bar' } }
    let(:retries) { 3 }
    let(:queue) { 'some-queue' }
    let(:auth_token) { Cloudtasker::Authenticator.verification_token }

    before do
      header 'Content-Type', 'application/json'
      header Cloudtasker::Config::RETRY_HEADER, retries
      header Cloudtasker::Config::TASK_ID_HEADER, task_id
    end

    shared_examples 'of a successful run call' do
      before do
        allow(Cloudtasker::WorkerHandler).to receive(:execute_from_payload!)
          .with(expected_payload)
          .and_return(true)
      end

      it 'calls Cloudtasker::WorkerHandler#execute_from_payload!' do
        post '/cloudtasker/run', request_body
        expect(
          Cloudtasker::WorkerHandler
        ).to have_received(:execute_from_payload!).with(expected_payload)
      end

      it 'suceeds with HTTP Status 204 - No Content' do
        post '/cloudtasker/run', request_body
        expect(last_response.status).to eq 204
      end
    end

    context 'with valid worker' do
      before { header 'Authorization', "Bearer #{auth_token}" }

      include_examples 'of a successful run call'
    end

    context 'with base64 encoded body' do
      let(:mime_type) { :text }
      let(:request_body) { Base64.encode64(payload.to_json) }

      before do
        header 'Authorization', "Bearer #{auth_token}"
        header 'Content-Transfer-Encoding', 'BASE64'
      end

      include_examples 'of a successful run call'
    end

    context 'with execution errors' do
      before do
        header 'Authorization', "Bearer #{auth_token}"

        allow(Cloudtasker::WorkerHandler).to receive(:execute_from_payload!)
          .with(expected_payload)
          .and_raise(ArgumentError)
      end

      it 'fails with HTTP Status 422 - Unprocessable Entity' do
        post '/cloudtasker/run', request_body
        expect(last_response.status).to eq 422
      end
    end

    context 'with dead worker' do
      before do
        header 'Authorization', "Bearer #{auth_token}"

        allow(Cloudtasker::WorkerHandler).to receive(:execute_from_payload!)
          .with(expected_payload)
          .and_raise(Cloudtasker::DeadWorkerError)
      end

      it 'succeeds with HTTP Status 205 - Reset Content' do
        post '/cloudtasker/run', request_body
        expect(last_response.status).to eq 205
      end
    end

    context 'with invalid worker' do
      before do
        header 'Authorization', "Bearer #{auth_token}"

        allow(Cloudtasker::WorkerHandler).to receive(:execute_from_payload!)
          .with(expected_payload)
          .and_raise(Cloudtasker::InvalidWorkerError)
      end

      it 'fails with HTTP Status 404 - Not Found' do
        post '/cloudtasker/run', request_body
        expect(last_response.status).to eq 404
      end
    end

    context 'with no authentication' do
      it 'fails with HTTP Status 401 - Unauthorized' do
        post '/cloudtasker/run', request_body
        expect(last_response.status).to eq 401
      end
    end

    context 'with invalid authentication' do
      before { header 'Authorization', "Bearer #{auth_token}aaa" }

      it 'fails with HTTP Status 401 - Unauthorized' do
        post '/cloudtasker/run', request_body
        expect(last_response.status).to eq 401
      end
    end
  end
end
