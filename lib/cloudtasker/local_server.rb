# frozen_string_literal: true

require 'cloudtasker/backend/redis_task'

module Cloudtasker
  # Process jobs stored in Redis.
  # Only to be used in development.
  class LocalServer
    # Max number of task requests sent to the processing server
    CONCURRENCY = (ENV['CLOUDTASKER_CONCURRENCY'] || 5).to_i

    #
    # Stop the local server.
    #
    def stop
      @done = true

      # Terminate threads and repush tasks
      @threads&.each do |t|
        t.terminate
        t['task']&.retry_later(0)
      end

      # Wait for main server to be done
      sleep 1 while @start&.alive?
    end

    #
    # Start the local server
    #
    #
    def start
      @start ||= Thread.new do
        until @done
          process_jobs
          sleep 1
        end
        Cloudtasker.logger.info('[Cloudtasker/Server] Local server exiting...')
      end
    end

    #
    # Process enqueued workers.
    #
    #
    def process_jobs
      @threads ||= []

      # Remove any done thread
      @threads.select!(&:alive?)

      # Process tasks
      while @threads.count < CONCURRENCY && (task = Cloudtasker::Backend::RedisTask.pop)
        @threads << Thread.new do
          Thread.current['task'] = task
          Thread.current['attempts'] = 0

          # Deliver task
          begin
            Thread.current['task'].deliver
          rescue Errno::ECONNREFUSED => e
            raise(e) unless Thread.current['attempts'] < 3

            # Retry on connection error, in case the web server is not
            # started yet.
            Thread.current['attempts'] += 1
            sleep(3)
            retry
          end
        end
      end
    end
  end
end
