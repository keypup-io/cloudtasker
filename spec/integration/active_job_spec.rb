# frozen_string_literal: true

require 'spec_helper'

if defined?(Rails)
  RSpec.describe 'ActiveJob integration' do
    let(:example_job_arguments) { [1, 'two', { three: 3 }] }

    let(:example_job_class) do
      Class.new(ActiveJob::Base) do
        def self.name
          'ExampleJob'
        end
      end
    end

    let(:expected_cloud_task_http_request_data) do
      a_hash_including(body: expected_cloud_task_body)
    end

    let(:expected_cloud_task_create_argument) do
      a_hash_including(http_request: expected_cloud_task_http_request_data, queue: 'default')
    end

    describe 'Calling .perform_later on an ActiveJob class' do
      let(:expected_cloud_task_body) do
        include_json(
          'worker' => 'ActiveJob::QueueAdapters::CloudtaskerAdapter::JobWrapper',
          'job_args' => a_collection_including(
            a_hash_including(
              'job_class' => example_job_class.name,
              'arguments' => ActiveJob::Arguments.serialize(example_job_arguments)
            )
          )
        )
      end

      context 'without any custom execution setup' do
        it 'enqueues the job to run as soon as possible' do
          expect(Cloudtasker::CloudTask).to receive(:create).with(expected_cloud_task_create_argument)
          example_job_class.perform_later(*example_job_arguments)
        end
      end

      context 'with a custom execution wait time' do
        let(:wait_time) { 1.week }
        let(:expected_calculated_datetime) { wait_time.from_now }
        let(:expected_cloud_task_create_argument) do
          a_hash_including(
            http_request: expected_cloud_task_http_request_data,
            queue: 'default',
            schedule_time: expected_calculated_datetime.to_i
          )
        end

        around { |e| Timecop.freeze { e.run } }

        it 'enqueues the job to run at the calculated datetime' do
          expect(Cloudtasker::CloudTask).to receive(:create).with(expected_cloud_task_create_argument)
          example_job_class.set(wait: wait_time).perform_later(*example_job_arguments)
        end
      end

      context 'with a different queue to execute the job' do
        let(:example_queue_name) { 'another-queue' }
        let(:expected_cloud_task_create_argument) do
          a_hash_including(
            http_request: expected_cloud_task_http_request_data,
            queue: example_queue_name
          )
        end

        it 'enqueues the job in the specified queue' do
          expect(Cloudtasker::CloudTask).to receive(:create).with(expected_cloud_task_create_argument)
          example_job_class.set(queue: example_queue_name).perform_later(*example_job_arguments)
        end
      end
    end
  end
end
