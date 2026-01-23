# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    # Wrapper class for Cloudtasker::Worker delegating to lock
    # and conflict strategies
    class Job
      attr_reader :worker, :call_opts

      # The default lock strategy to use. Defaults to "no lock".
      DEFAULT_LOCK = UniqueJob::Lock::NoOp

      # Warning message when final lock cannot be acquired after scheduling
      LOCK_FINALIZATION_WARNING = 'A provisional lock was acquired before enqueuing the job but the ' \
                                  'lock could not be finalized after enqueuing the job. This means that ' \
                                  'it took longer than lock_provisional_ttl to enqueue the job. See ' \
                                  'Worker#lock_provisional_ttl option.'

      #
      # Build a new instance of the class.
      #
      # @param [Cloudtasker::Worker] worker The worker at hand
      # @param [Hash] worker The worker options
      #
      def initialize(worker, opts = {})
        @worker = worker
        @call_opts = opts.to_h
      end

      #
      # Return the worker configuration options.
      #
      # @return [Hash] The worker configuration options.
      #
      def options
        worker.class.cloudtasker_options_hash
      end

      #
      # Return the Time To Live (TTL) that should be set in Redis for
      # the lock key. Having a TTL on lock keys ensures that jobs
      # do not end up stuck due to a dead lock situation.
      #
      # The TTL is calculated using schedule time + expected
      # max job duration.
      #
      # The expected max job duration is set to 10 minutes by default.
      # This value was chosen because it's twice the default request timeout
      # value in Cloud Run. This leaves enough room for queue lag (5 minutes)
      # + job processing (5 minutes).
      #
      # Queue lag is certainly the most unpredictable factor here.
      # Job processing time is less of a factor. Jobs running for more than 5 minutes
      # should be split into sub-jobs to limit invocation time over HTTP. Cloudtasker batch
      # jobs can help achieve that if you need to make one big job split into sub-jobs "atomic".
      #
      # The default lock key expiration of "time_at + 10 minutes" may look aggressive but it
      # is still a better choice than potentially having real-time jobs stuck for X hours.
      #
      # The expected max job duration can be configured via the `lock_ttl`
      # option on the job itself.
      #
      # @return [Integer] The TTL in seconds
      #
      def lock_ttl
        now = Time.now.to_i

        # Get scheduled at and lock duration
        scheduled_at = [call_opts[:time_at].to_i, now].compact.max
        lock_duration = (options[:lock_ttl] || Cloudtasker::UniqueJob.lock_ttl).to_i

        # Return the TTL, which is the configured lock_duration at minima
        [lock_duration, scheduled_at + lock_duration - now].max
      end

      #
      # A provisional lock uses a very short duration and aims
      # at covering the time it takes for the job to be enqueued through
      # the client middleware chain.
      #
      # If the application crashes during this
      # time (e.g. OOM), at least the job won't be locked for an extended period
      # of time (which may span across a parent job retry, for instance)
      #
      # This TTL can be configured via the `lock_provisional_ttl` option on
      # the job itself.
      #
      # @return [Integer] The TTL in seconds
      #
      def lock_provisional_ttl
        (options[:lock_provisional_ttl] || Cloudtasker::UniqueJob.lock_provisional_ttl).to_i
      end

      #
      # Return the instantiated lock.
      #
      # @return [Any] The instantiated lock
      #
      def lock_instance
        @lock_instance ||=
          begin
            # Infer lock class and get instance
            lock_name = options[:lock]
            lock_klass = Lock.const_get(lock_name.to_s.split('_').collect(&:capitalize).join)
            lock_klass.new(self)
          rescue NameError
            DEFAULT_LOCK.new(self)
          end
      end

      #
      # Return the list of arguments used for job uniqueness.
      #
      # @return [Array<any>] The list of unique arguments
      #
      def unique_args
        worker.try(:unique_args, worker.job_args) || worker.job_args
      end

      #
      # The base unique scope generated from lock options
      #
      # @return [Hash] A scope hash
      #
      def base_unique_scope
        if options[:lock_per_batch] && defined?(Cloudtasker::Batch::Job)
          key = Cloudtasker::Batch::Job.key(:parent_id).to_sym
          worker.job_meta.to_h.slice(key)
        else
          {}
        end
      end

      #
      # Return a scope to be included in the digest hash
      #
      # @return [Hash] A scope hash
      #
      def unique_scope
        base_unique_scope.to_h.merge(worker.try(:unique_scope).to_h)
      end

      #
      # Return a unique description of the job in hash format.
      #
      # @return [Hash] Representation of the unique job in hash format.
      #
      def digest_hash
        @digest_hash ||= {
          class: worker.class.to_s,
          unique_args: unique_args,
          unique_scope: unique_scope.presence
        }.compact
      end

      #
      # Return the worker job ID.
      #
      # @return [String] The worker job ID.
      #
      def id
        worker.job_id
      end

      #
      # Return the ID of the unique job.
      #
      # @return [String] The ID of the job.
      #
      def unique_id
        Digest::SHA256.hexdigest(digest_hash.to_json)
      end

      #
      # Return the Global ID of the unique job. The gid
      # includes the UniqueJob namespace.
      #
      # @return [String] The global ID of the job
      #
      def unique_gid
        [self.class.to_s.underscore, unique_id].join('/')
      end

      #
      # Return the Cloudtasker redis client.
      #
      # @return [Cloudtasker::RedisClient] The cloudtasker redis client.
      #
      def redis
        @redis ||= Cloudtasker::RedisClient.new
      end

      #
      # Acquire a new unique job lock or check that the lock is
      # currently allocated to this job.
      #
      # Raise a `Cloudtasker::UniqueJob::LockError` if the lock
      # if taken by another job.
      #
      def lock!
        lock_acquired = redis.set(unique_gid, id, nx: true, ex: lock_ttl)
        lock_already_acquired = !lock_acquired && redis.get(unique_gid) == id

        raise(LockError) unless lock_acquired || lock_already_acquired
      end

      #
      # Acquire a provisional lock, yield, then set a final lock.
      #
      # This method is designed for scheduling operations where you need to:
      # 1. Acquire a provisional lock to prevent concurrent scheduling
      # 2. Perform the scheduling operation (yield)
      # 3. Set a final lock with proper TTL after scheduling succeeds
      #
      # Raises a `Cloudtasker::UniqueJob::LockError` if the provisional lock
      # cannot be acquired.
      #
      # @return [Any] The return value of the block
      #
      def lock_for_scheduling!
        # Step 1: Acquire provisional lock
        # Check if the lock is already acquired from a previous run
        acquired = redis.get(unique_gid) == id

        # Set the lock exclusively, if not acquired already.
        # Refresh the duration otherwise.
        lock_acquired = redis.set(unique_gid, id, nx: !acquired, ex: lock_provisional_ttl)
        raise(LockError) unless lock_acquired

        # Step 2: Yield to perform scheduling operation
        result = yield

        # Step 3: Set final lock
        # Check if the lock is still held by this job
        acquired = redis.get(unique_gid) == id

        # Set the lock with final duration
        # If already acquired, refresh with final TTL
        # If not acquired (expired or taken), try to acquire exclusively
        final_lock_acquired = redis.set(unique_gid, id, nx: !acquired, ex: lock_ttl)

        # Log a warning if final lock could not be acquired
        # The job has already been enqueued at this point, so raising an error is useless
        worker.logger.warn(LOCK_FINALIZATION_WARNING) unless final_lock_acquired

        # Return the result of the block
        result
      end

      #
      # Delete the job lock.
      #
      def unlock!
        locked_id = redis.get(unique_gid)
        redis.del(unique_gid) if locked_id == id
      end
    end
  end
end
