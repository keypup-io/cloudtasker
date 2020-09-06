# frozen_string_literal: true

# rubocop:disable RSpec/ContextWording
RSpec.shared_context 'of Cloudtasker ActiveJob instantiation' do
  let :example_job_class do
    Class.new(ActiveJob::Base) do
      def self.name
        'ExampleJob'
      end
    end
  end

  let(:example_job_setup) { {} }
  let(:example_job_arguments) { [1, 'two', { three: 3 }] }
  let(:example_job) { example_job_class.new(*example_job_arguments) }
  
  let :example_job_serialization do
    example_job
      .serialize
      .except(*%w[executions provider_job_id priority job_id queue_name])
  end

  let :example_worker_args do
    {
      job_queue: example_job.queue_name,
      job_args: [example_job_serialization],
      job_id: example_job.job_id
    }
  end
end
# rubocop:enable RSpec/ContextWording
