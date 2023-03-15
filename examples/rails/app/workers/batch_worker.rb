# frozen_string_literal: true

class BatchWorker
  include Cloudtasker::Worker

  def perform(level = 0, instance = 0)
    Rails.logger.info("#{self.class} level=#{level} instance=#{instance} | starting...")
    # sleep(1)

    # Enqueue children
    10.times { |n| batch.add(BatchWorker, level + 1, n) } if level < 2

    Rails.logger.info("#{self.class} level=#{level} instance=#{instance} | done!")
  end

  def on_child_complete(child)
    msg = [
      "#{self.class} level=#{job_args[0].to_i} instance=#{job_args[1].to_i}",
      "on_child_complete level=#{child.job_args[0]} instance=#{child.job_args[1]}"
    ].join(' | ')
    Rails.logger.info(msg)
  end

  def on_batch_node_complete(child)
    msg = [
      "#{self.class} level=#{job_args[0].to_i} instance=#{job_args[1].to_i}",
      "on_batch_node_complete level=#{child.job_args[0].to_i} instance=#{child.job_args[1].to_i}"
    ].join(' | ')
    Rails.logger.info(msg)
  end

  def on_batch_complete
    msg = [
      "#{self.class} level=#{job_args[0].to_i} instance=#{job_args[1].to_i}",
      'on_batch_complete'
    ].join(' | ')
    Rails.logger.info(msg)
  end
end
