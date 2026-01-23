# frozen_string_literal: true

require_relative 'unique_job/middleware'

Cloudtasker::UniqueJob::Middleware.configure

module Cloudtasker
  # UniqueJob configurator
  module UniqueJob
    # The maximum duration a lock can remain in place
    # after schedule time.
    DEFAULT_LOCK_TTL = 10 * 60 # 10 minutes

    # The maximum duration of the provisional lock while
    # enqueuing a job.
    DEFAULT_LOCK_PROVISIONAL_TTL = 3

    class << self
      attr_writer :lock_ttl, :lock_provisional_ttl

      # Configure the middleware
      def configure
        yield(self)
      end

      #
      # Return the max TTL for locks
      #
      # @return [Integer] The lock TTL.
      #
      def lock_ttl
        @lock_ttl || DEFAULT_LOCK_TTL
      end

      #
      # Return the provisional TTL for locks
      #
      # @return [Integer] The lock TTL.
      #
      def lock_provisional_ttl
        @lock_provisional_ttl || DEFAULT_LOCK_PROVISIONAL_TTL
      end
    end
  end
end
