# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'ActiveJob integration' do
  let(:example_job_arguments) { [1, 'two', { three: 3 }] }
  let(:example_verification_token) { 'VERIFICATION_TOKEN' }

  let :example_job_class do
    Class.new(ActiveJob::Base) do
      def self.name
        'ExampleJob'
      end
    end
  end

  let :expected_cloud_task_http_request_data do
    a_hash_including body: expected_cloud_task_body,
                     headers: a_hash_including(
                       'Authorization' => "Bearer #{example_verification_token}"
                     )
  end

  let :expected_cloud_task_create_argument do
    a_hash_including http_request: expected_cloud_task_http_request_data,
                     queue: 'default'
  end

  before do
    # I'm not sure if this is "knowing too much about the implementation"...
    allow(Cloudtasker::Authenticator)
      .to receive(:verification_token).and_return example_verification_token
  end

  describe 'Calling .perform_later on an ActiveJob class' do
    let :expected_cloud_task_body do
      job_arguments = ActiveJob::Arguments.serialize example_job_arguments
      include_json 'worker' => 'ActiveJob::QueueAdapters::CloudtaskerAdapter::Worker',
                   'job_args' => a_collection_including(
                     a_hash_including(
                       'job_class' => example_job_class.name,
                       'arguments' => job_arguments
                     )
                   )
    end

    context 'without any custom execution setup' do
      it 'enqueues the job to run as soon as possible' do
        expect(Cloudtasker::CloudTask)
          .to receive(:create).with expected_cloud_task_create_argument
  
        example_job_class.perform_later(*example_job_arguments)
      end
    end

    context 'with a custom execution wait time' do
      let!(:expected_calculated_datetime) { 1.week.from_now }

      let :expected_cloud_task_create_argument do
        a_hash_including http_request: expected_cloud_task_http_request_data,
                         queue: 'default',
                         schedule_time: expected_calculated_datetime.to_i
      end

      it 'enqueues the job to run at the calculated datetime' do
        expect(Cloudtasker::CloudTask)
          .to receive(:create).with expected_cloud_task_create_argument

        example_job_class
          .set(wait: 1.week)
          .perform_later(*example_job_arguments)
      end
    end

    context 'with a different queue to execute the job' do
      let(:example_queue_name) { 'another-queue' }

      let :expected_cloud_task_create_argument do
        a_hash_including http_request: expected_cloud_task_http_request_data,
                         queue: example_queue_name
      end

      it 'enqueues the job in the specified queue' do
        expect(Cloudtasker::CloudTask)
          .to receive(:create).with expected_cloud_task_create_argument

        example_job_class
          .set(queue: example_queue_name)
          .perform_later(*example_job_arguments)
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
