# frozen_string_literal: true

class ExampleJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Rails.logger.info('Example job starting...')
    Rails.logger.info(args.inspect)
    sleep(3)
    Rails.logger.info('Example job done!')
  end
end
