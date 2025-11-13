# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Propagated Queues' do
  let(:parent_queue) { TestPropagateQueueWorker.cloudtasker_options_hash[:queue] }
  let(:child_queue) { TestPropagateQueueSubWorker.cloudtasker_options_hash[:queue] }

  before do
    Cloudtasker::Testing.fake! do
      TestPropagateQueueWorker.perform_now
      TestPropagateQueueSubWorker.perform_async
    end
  end

  it 'propagates the parent queue on child workers' do
    # First job is enqueued via TestPropagateQueueWorker
    expect(TestPropagateQueueSubWorker.jobs[0]).to have_attributes(queue: parent_queue)
  end

  it 'does not impact standalone jobs' do
    # Second job is enqueued independently in the before block
    expect(TestPropagateQueueSubWorker.jobs[1]).to have_attributes(queue: child_queue)
  end
end
