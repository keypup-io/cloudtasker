# frozen_string_literal: true

require 'cloudtasker/backend/redis_task'

module Cloudtasker
  # Process jobs stored in Redis.
  # Only to be used in development.
  class LocalServer
    # Max number of task requests sent to the processing server
    CONCURRENCY = (ENV['CLOUDTASKER_CONCURRENCY'] || 5).to_i

    # Default number of threads to allocate to process a specific queue
    QUEUE_CONCURRENCY = 1

    #
    # Stop the local server.
    #
    def stop
      @done = true

      # Terminate threads and repush tasks
      @threads&.values&.flatten&.each do |t|
        t.terminate
        t['task']&.retry_later(0, is_error: false)
      end

      # Wait for main server to be done
      sleep 1 while @start&.alive?
    end

    #
    # Start the local server
    #
    # @param [Hash] opts Server options.
    #
    #
    def start(opts = {})
      # Extract queues to process
      queues = opts[:queues].to_a.any? ? opts[:queues] : [[nil, CONCURRENCY]]

      # Display start banner
      queue_labels = queues.map { |n, c| "#{n || 'all'}=#{c || QUEUE_CONCURRENCY}" }.join(' ')
      Cloudtasker.logger.info("[Cloudtasker/Server] Processing queues: #{queue_labels}")

      # Start processing queues
      @start ||= Thread.new do
        until @done
          queues.each { |(n, c)| process_jobs(n, c) }
          sleep 1
        end
        Cloudtasker.logger.info('[Cloudtasker/Server] Local server exiting...')
      end
    end

    #
    # Process enqueued workers.
    #
    #
    def process_jobs(queue = nil, concurrency = nil)
      @threads ||= {}
      @threads[queue] ||= []
      max_threads = (concurrency || QUEUE_CONCURRENCY).to_i

      # Remove any done thread
      @threads[queue].select!(&:alive?)

      # Process tasks
      while @threads[queue].count < max_threads && (task = Cloudtasker::Backend::RedisTask.pop(queue))
        @threads[queue] << Thread.new { process_task(task) }
      end
    end

    #
    # Process a given task
    #
    # @param [Cloudtasker::CloudTask] task The task to process
    #
    def process_task(task)
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
