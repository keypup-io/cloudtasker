# frozen_string_literal: true

module Cloudtasker
  # Cloud Task based workers
  module Worker
    # Add class method to including class
    def self.included(base)
      base.extend(ClassMethods)
      base.attr_writer :job_queue
      base.attr_accessor :job_args, :job_id, :job_meta, :job_reenqueued, :job_retries,
                         :perform_started_at, :perform_ended_at, :task_id
    end

    #
    # Return a worker instance from a serialized worker.
    # A worker can be serialized by calling `MyWorker#to_json`
    #
    # @param [String] json Worker serialized as json.
    #
    # @return [Cloudtasker::Worker, nil] The instantiated worker.
    #
    def self.from_json(json)
      from_hash(JSON.parse(json))
    rescue JSON::ParserError
      nil
    end

    #
    # Return a worker instance from a worker hash description.
    # A worker hash description is typically generated by calling `MyWorker#to_h`
    #
    # @param [Hash] hash A worker hash description.
    #
    # @return [Cloudtasker::Worker, nil] The instantiated worker.
    #
    def self.from_hash(hash)
      # Symbolize metadata keys and stringify job arguments
      payload = JSON.parse(hash.to_json, symbolize_names: true)
      payload[:job_args] = JSON.parse(payload[:job_args].to_json)

      # Extract worker parameters
      klass_name = payload&.dig(:worker)
      return nil unless klass_name

      # Check that worker class is a valid worker
      worker_klass = Object.const_get(klass_name)
      return nil unless worker_klass.include?(self)

      # Return instantiated worker
      worker_klass.new(payload.slice(:job_queue, :job_args, :job_id, :job_meta, :job_retries, :task_id))
    rescue NameError
      nil
    end

    # Module class methods
    module ClassMethods
      #
      # Set the worker runtime options.
      #
      # @param [Hash] opts The worker options.
      #
      # @return [Hash] The options set.
      #
      def cloudtasker_options(opts = {})
        opt_list = opts&.map { |k, v| [k.to_sym, v] } || [] # symbolize
        @cloudtasker_options_hash = Hash[opt_list]
      end

      #
      # Return the worker runtime options.
      #
      # @return [Hash] The worker runtime options.
      #
      def cloudtasker_options_hash
        @cloudtasker_options_hash || {}
      end

      #
      # Enqueue worker in the backgroundf.
      #
      # @param [Array<any>] *args List of worker arguments
      #
      # @return [Cloudtasker::CloudTask] The Google Task response
      #
      def perform_async(*args)
        schedule(args: args)
      end

      #
      # Enqueue worker and delay processing.
      #
      # @param [Integer, nil] interval The delay in seconds.
      # @param [Array<any>] *args List of worker arguments.
      #
      # @return [Cloudtasker::CloudTask] The Google Task response
      #
      def perform_in(interval, *args)
        schedule(args: args, time_in: interval)
      end

      #
      # Enqueue worker and delay processing.
      #
      # @param [Time, Integer] time_at The time at which the job should run.
      # @param [Array<any>] *args List of worker arguments
      #
      # @return [Cloudtasker::CloudTask] The Google Task response
      #
      def perform_at(time_at, *args)
        schedule(args: args, time_at: time_at)
      end

      #
      # Enqueue a worker with explicity options.
      #
      # @param [Array<any>] args The job arguments.
      # @param [Time, Integer] time_in The delay in seconds.
      # @param [Time, Integer] time_at The time at which the job should run.
      # @param [String, Symbol] queue The queue on which the worker should run.
      #
      # @return [Cloudtasker::CloudTask] The Google Task response
      #
      def schedule(args: nil, time_in: nil, time_at: nil, queue: nil)
        new(job_args: args, job_queue: queue).schedule({ interval: time_in, time_at: time_at }.compact)
      end

      #
      # Return the numbeer of times this worker will be retried.
      #
      # @return [Integer] The number of retries.
      #
      def max_retries
        cloudtasker_options_hash[:max_retries] || Cloudtasker.config.max_retries
      end
    end

    #
    # Build a new worker instance.
    #
    # @param [Array<any>] job_args The list of perform args.
    # @param [String] job_id A unique ID identifying this job.
    #
    def initialize(job_queue: nil, job_args: nil, job_id: nil, job_meta: {}, job_retries: 0, task_id: nil)
      @job_args = job_args || []
      @job_id = job_id || SecureRandom.uuid
      @job_meta = MetaStore.new(job_meta)
      @job_retries = job_retries || 0
      @job_queue = job_queue
      @task_id = task_id
    end

    #
    # Return the class name of the worker.
    #
    # @return [String] The class name.
    #
    def job_class_name
      self.class.to_s
    end

    #
    # Return the queue to use for this worker.
    #
    # @return [String] The name of queue.
    #
    def job_queue
      (@job_queue ||= self.class.cloudtasker_options_hash[:queue] || Config::DEFAULT_JOB_QUEUE).to_s
    end

    #
    # Return the Dispatch deadline duration. Cloud Tasks will timeout the job after
    # this duration is elapsed.
    #
    # @return [Integer] The value in seconds.
    #
    def dispatch_deadline
      @dispatch_deadline ||= [
        [
          Config::MIN_DISPATCH_DEADLINE,
          (self.class.cloudtasker_options_hash[:dispatch_deadline] || Cloudtasker.config.dispatch_deadline).to_i
        ].max,
        Config::MAX_DISPATCH_DEADLINE
      ].min
    end

    #
    # Return the Cloudtasker logger instance.
    #
    # @return [Logger, any] The cloudtasker logger.
    #
    def logger
      @logger ||= WorkerLogger.new(self)
    end

    #
    # Execute the worker by calling the `perform` with the args.
    #
    # @return [Any] The result of the perform.
    #
    def execute
      logger.info('Starting job...')

      # Perform job logic
      resp = execute_middleware_chain

      # Log job completion and return result
      logger.info("Job done after #{job_duration}s") { { duration: job_duration } }
      resp
    rescue DeadWorkerError => e
      logger.info("Job dead after #{job_duration}s and #{job_retries} retries") { { duration: job_duration } }
      raise(e)
    rescue StandardError => e
      logger.info("Job failed after #{job_duration}s") { { duration: job_duration } }
      raise(e)
    end

    #
    # Return a unix timestamp specifying when to run the task.
    #
    # @param [Integer, nil] interval The time to wait.
    # @param [Integer, nil] time_at The time at which the job should run.
    #
    # @return [Integer, nil] The Unix timestamp.
    #
    def schedule_time(interval: nil, time_at: nil)
      return nil unless interval || time_at

      # Generate the complete Unix timestamp
      (time_at || Time.now).to_i + interval.to_i
    end

    #
    # Enqueue a worker, with or without delay.
    #
    # @param [Integer] interval The delay in seconds.
    # @param [Time, Integer] interval The time at which the job should run
    #
    # @return [Cloudtasker::CloudTask] The Google Task response
    #
    def schedule(**args)
      # Evaluate when to schedule the job
      time_at = schedule_time(args)

      # Schedule job through client middlewares
      Cloudtasker.config.client_middleware.invoke(self, time_at: time_at) do
        WorkerHandler.new(self).schedule(time_at: time_at)
      end
    end

    #
    # Helper method used to re-enqueue the job. Re-enqueued
    # jobs keep the same job_id.
    #
    # This helper may be useful when jobs must pause activity due to external
    # factors such as when a third-party API is throttling the rate of API calls.
    #
    # @param [Integer] interval Delay to wait before processing the job again (in seconds).
    #
    # @return [Cloudtasker::CloudTask] The Google Task response
    #
    def reenqueue(interval)
      @job_reenqueued = true
      schedule(interval: interval)
    end

    #
    # Return a new instance of the worker with the same args and metadata
    # but with a different id.
    #
    # @return [Cloudtasker::Worker] <description>
    #
    def new_instance
      self.class.new(job_queue: job_queue, job_args: job_args, job_meta: job_meta)
    end

    #
    # Return a hash description of the worker.
    #
    # @return [Hash] The worker hash description.
    #
    def to_h
      {
        worker: self.class.to_s,
        job_id: job_id,
        job_args: job_args,
        job_meta: job_meta.to_h,
        job_retries: job_retries,
        job_queue: job_queue,
        task_id: task_id
      }
    end

    #
    # Return a json representation of the worker.
    #
    # @param [Array<any>] *args Arguments passed to to_json.
    #
    # @return [String] The worker json representation.
    #
    def to_json(*args)
      to_h.to_json(*args)
    end

    #
    # Equality operator.
    #
    # @param [Any] other The object to compare.
    #
    # @return [Boolean] True if the object is equal.
    #
    def ==(other)
      other.is_a?(self.class) && other.job_id == job_id
    end

    #
    # Return the max number of retries allowed for this job.
    #
    # The order of precedence for retry lookup is:
    # - Worker `max_retries` method
    # - Class `max_retries` option
    # - Cloudtasker `max_retries` config option
    #
    # @return [Integer] The number of retries
    #
    def job_max_retries
      @job_max_retries ||= (try(:max_retries, *job_args) || self.class.max_retries)
    end

    #
    # Return true if the job must declared dead upon raising
    # an error.
    #
    # @return [Boolean] True if the job must die on error.
    #
    def job_must_die?
      job_retries >= job_max_retries
    end

    #
    # Return true if the job has strictly excceeded its maximum number
    # of retries.
    #
    # Used a preemptive filter when running the job.
    #
    # @return [Boolean] True if the job is dead
    #
    def job_dead?
      job_retries > job_max_retries
    end

    #
    # Return true if the job arguments are missing.
    #
    # This may happen if a job
    # was successfully run but retried due to Cloud Task dispatch deadline
    # exceeded. If the arguments were stored in Redis then they may have
    # been flushed already after the successful completion.
    #
    # If job arguments are missing then the job will simply be declared dead.
    #
    # @return [Boolean] True if the arguments are missing.
    #
    def arguments_missing?
      job_args.empty? && [0, -1].exclude?(method(:perform).arity)
    end

    #
    # Return the time taken (in seconds) to perform the job. This duration
    # includes the middlewares and the actual perform method.
    #
    # @return [Float] The time taken in seconds as a floating point number.
    #
    def job_duration
      return 0.0 unless perform_ended_at && perform_started_at

      (perform_ended_at - perform_started_at).ceil(3)
    end

    #
    # Run worker callback.
    #
    # @param [String, Symbol] callback The callback to run.
    # @param [Array<any>] *args The callback arguments.
    #
    # @return [any] The callback return value
    #
    def run_callback(callback, *args)
      try(callback, *args)
    end

    #=============================
    # Private
    #=============================
    private

    #
    # Flag the worker as dead by invoking the on_dead hook
    # and raising a DeadWorkerError
    #
    # @param [Exception, nil] error An optional exception to be passed to the DeadWorkerError.
    #
    def flag_as_dead(error = nil)
      run_callback(:on_dead, error || DeadWorkerError.new)
    ensure
      raise(DeadWorkerError, error)
    end

    #
    # Execute the worker perform method through the middleware chain.
    #
    # @return [Any] The result of the perform method.
    #
    def execute_middleware_chain
      self.perform_started_at = Time.now

      Cloudtasker.config.server_middleware.invoke(self) do
        # Immediately abort the job if it is already dead
        flag_as_dead if job_dead?
        flag_as_dead(MissingWorkerArgumentsError.new('worker arguments are missing')) if arguments_missing?

        begin
          # Perform the job
          perform(*job_args)
        rescue StandardError => e
          run_callback(:on_error, e)
          return raise(e) unless job_must_die?

          # Flag job as dead
          flag_as_dead(e)
        end
      end
    ensure
      self.perform_ended_at = Time.now
    end
  end
end
