# frozen_string_literal: true

require 'redis'
require 'connection_pool'

module Cloudtasker
  # A wrapper with helper methods for redis
  class RedisClient
    # Suffix added to cache keys when locking them
    LOCK_KEY_PREFIX = 'cloudtasker/lock'
    LOCK_DURATION = 2 # seconds
    LOCK_WAIT_DURATION = 0.03 # seconds

    # Default pool size used for Redis
    DEFAULT_POOL_SIZE = ENV.fetch('RAILS_MAX_THREADS') { 25 }
    DEFAULT_POOL_TIMEOUT = 5

    def self.client
      @client ||= begin
        pool_size = Cloudtasker.config.redis&.dig(:pool_size) || DEFAULT_POOL_SIZE
        pool_timeout = Cloudtasker.config.redis&.dig(:pool_timeout) || DEFAULT_POOL_TIMEOUT
        ConnectionPool.new(size: pool_size, timeout: pool_timeout) do
          Redis.new(Cloudtasker.config.redis || {})
        end
      end
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
      return nil unless (val = get(key.to_s))

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
      set(key.to_s, content.to_json)
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
    # @param [Integer] max_wait The number of seconds after which the lock will be cleared anyway.
    #
    def with_lock(cache_key, max_wait: nil)
      return nil unless cache_key

      # Set max wait
      max_wait = (max_wait || LOCK_DURATION).to_i

      # Wait to acquire lock
      lock_key = [LOCK_KEY_PREFIX, cache_key].join('/')
      client.with do |conn|
        sleep(LOCK_WAIT_DURATION) until conn.set(lock_key, true, nx: true, ex: max_wait)
      end

      # yield content
      yield
    ensure
      del(lock_key)
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
      client.with do |conn|
        while cursor != 0
          scan = conn.scan(cursor || 0, match: pattern)
          list += scan[1]
          cursor = scan[0].to_i
        end
      end

      list
    end

    # rubocop:disable Style/MissingRespondToMissing
    if RUBY_VERSION < '3'
      #
      # Delegate all methods to the redis client.
      # Old delegation method.
      #
      # @param [String, Symbol] name The method to delegate.
      # @param [Array<any>] *args The list of method positional arguments.
      # @param [Hash<any>] *kwargs The list of method keyword arguments.
      # @param [Proc] &block Block passed to the method.
      #
      # @return [Any] The method return value
      #
      def method_missing(name, *args, &block)
        if Redis.method_defined?(name)
          client.with { |c| c.send(name, *args, &block) }
        else
          super
        end
      end
    else
      #
      # Delegate all methods to the redis client.
      # Ruby 3 delegation method style.
      #
      # @param [String, Symbol] name The method to delegate.
      # @param [Array<any>] *args The list of method positional arguments.
      # @param [Hash<any>] *kwargs The list of method keyword arguments.
      # @param [Proc] &block Block passed to the method.
      #
      # @return [Any] The method return value
      #
      def method_missing(name, *args, **kwargs, &block)
        if Redis.method_defined?(name)
          client.with { |c| c.send(name, *args, **kwargs, &block) }
        else
          super
        end
      end
    end
    # rubocop:enable Style/MissingRespondToMissing

    #
    # Check if the class respond to a certain method.
    #
    # @param [String, Symbol] name The name of the method.
    # @param [Boolean] include_private Whether to check private methods or not. Default to false.
    #
    # @return [Boolean] Return true if the class respond to this method.
    #
    def respond_to_missing?(name, include_private = false)
      Redis.method_defined?(name) || super
    end
  end
end
