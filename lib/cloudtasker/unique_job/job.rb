# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    # Wrapper class for Cloudtasker::Worker delegating to lock
    # and conflict strategies
    class Job
      attr_reader :worker, :call_opts

      # The default lock strategy to use. Defaults to "no lock".
      DEFAULT_LOCK = UniqueJob::Lock::NoOp

      #
      # Build a new instance of the class.
      #
      # @param [Cloudtasker::Worker] worker The worker at hand
      # @param [Hash] worker The worker options
      #
      def initialize(worker, opts = {})
        @worker = worker
        @call_opts = opts
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

        # Return TTL
        scheduled_at + lock_duration - now
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
      # Return a unique description of the job in hash format.
      #
      # @return [Hash] Representation of the unique job in hash format.
      #
      def digest_hash
        @digest_hash ||= {
          class: worker.class.to_s,
          unique_args: unique_args
        }
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
      # Delete the job lock.
      #
      def unlock!
        locked_id = redis.get(unique_gid)
        redis.del(unique_gid) if locked_id == id
      end
    end
  end
end
