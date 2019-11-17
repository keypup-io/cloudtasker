# frozen_string_literal: true

module Cloudtasker
  module UniqueJob
    # Wrapper class for Cloudtasker::Worker delegating to lock
    # and conflict strategies
    class Job
      attr_reader :worker

      # The default lock strategy to use. Defaults to "no lock".
      DEFAULT_LOCK = UniqueJob::Lock::NoOp

      # Key Namespace used for object saved under this class
      SUB_NAMESPACE = 'job'

      #
      # Build a new instance of the class.
      #
      # @param [Cloudtasker::Worker] worker The worker at hand
      #
      def initialize(worker)
        @worker = worker
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
      # Return the instantiated lock.
      #
      # @return [Any] The instantiated lock
      #
      def lock_instance
        @lock_instance ||=
          begin
            # Infer lock class and get instance
            lock_name = options[:lock] || options['lock']
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
      # @return [Class] The Cloudtasker::RedisClient wrapper.
      #
      def redis
        Cloudtasker::RedisClient
      end

      #
      # Acquire a new unique job lock or check that the lock is
      # currently allocated to this job.
      #
      # Raise a `Cloudtasker::UniqueJob::LockError` if the lock
      # if taken by another job.
      #
      def lock!
        redis.with_lock(unique_gid) do
          locked_id = redis.get(unique_gid)

          # Abort job lock process if lock is already taken by another job
          raise(LockError, locked_id) if locked_id && locked_id != id

          # Take job lock if the lock is currently free
          redis.set(unique_gid, id) unless locked_id
        end
      end

      #
      # Delete the job lock.
      #
      def unlock!
        redis.with_lock(unique_gid) do
          locked_id = redis.get(unique_gid)
          redis.del(unique_gid) if locked_id == id
        end
      end
    end
  end
end
