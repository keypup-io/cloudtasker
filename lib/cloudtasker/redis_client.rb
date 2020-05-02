# frozen_string_literal: true

require 'redis'

module Cloudtasker
  # A wrapper with helper methods for redis
  class RedisClient
    # Suffix added to cache keys when locking them
    LOCK_KEY_PREFIX = 'cloudtasker/lock'
    LOCK_DURATION = 2 # seconds
    LOCK_WAIT_DURATION = 0.03 # seconds

    def self.client
      @client ||= Redis.new(Cloudtasker.config.redis || {})
    end

    #
    # Return the underlying redis client.
    #
    # @return [Redis] The redis client.
    #
    def client
      @client ||= self.class.client
    end

    #
    # Get a cache entry and parse it as JSON.
    #
    # @param [String, Symbol] key The cache key to fetch.
    #
    # @return [Hash, Array] The content of the cache key, parsed as JSON.
    #
    def fetch(key)
      return nil unless (val = client.get(key.to_s))

      JSON.parse(val, symbolize_names: true)
    rescue JSON::ParserError
      nil
    end

    #
    # Write a cache entry as JSON.
    #
    # @param [String, Symbol] key The cache key to write.
    # @param [Hash, Array] content The content to write.
    #
    # @return [String] Redis response code.
    #
    def write(key, content)
      client.set(key.to_s, content.to_json)
    end

    #
    # Acquire a lock on a cache entry.
    #
    # Locks are enforced to be short-lived (2s).
    # The yielded block should limit its logic to short operations (e.g. redis get/set).
    #
    # @example
    #   redis = RedisClient.new
    #   redis.with_lock('foo')
    #     content = redis.fetch('foo')
    #     redis.set(content.merge(bar: 'bar).to_json)
    #   end
    #
    # @param [String] cache_key The cache key to access.
    #
    def with_lock(cache_key)
      return nil unless cache_key

      # Wait to acquire lock
      lock_key = [LOCK_KEY_PREFIX, cache_key].join('/')
      sleep(LOCK_WAIT_DURATION) until client.set(lock_key, true, nx: true, ex: LOCK_DURATION)

      # yield content
      yield
    ensure
      client.del(lock_key)
    end

    #
    # Clear all redis keys
    #
    # @return [Integer] The number of keys deleted
    #
    def clear
      all_keys = keys
      return 0 if all_keys.empty?

      # Delete all keys
      del(*all_keys)
    end

    #
    # Return all keys matching the provided patterns.
    #
    # @param [String] pattern A redis compatible pattern.
    #
    # @return [Array<String>] The list of matching keys
    #
    def search(pattern)
      # Initialize loop variables
      cursor = nil
      list = []

      # Scan and capture matching keys
      while cursor != 0
        scan = client.scan(cursor || 0, match: pattern)
        list += scan[1]
        cursor = scan[0].to_i
      end

      list
    end

    #
    # Delegate all methods to the redis client.
    #
    # @param [String, Symbol] name The method to delegate.
    # @param [Array<any>] *args The list of method arguments.
    # @param [Proc] &block Block passed to the method.
    #
    # @return [Any] The method return value
    #
    def method_missing(name, *args, &block)
      if client.respond_to?(name)
        client.send(name, *args, &block)
      else
        super
      end
    end

    #
    # Check if the class respond to a certain method.
    #
    # @param [String, Symbol] name The name of the method.
    # @param [Boolean] include_private Whether to check private methods or not. Default to false.
    #
    # @return [Boolean] Return true if the class respond to this method.
    #
    def respond_to_missing?(name, include_private = false)
      client.respond_to?(name) || super
    end
  end
end
