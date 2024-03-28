# frozen_string_literal: true

module Cloudtasker
  module Storable
    # Add ability to store and pull workers in Redis under a specific namespace
    module Worker
      # Add class method to including class
      def self.included(base)
        base.extend(ClassMethods)
      end

      # Module class methods
      module ClassMethods
        #
        # Return the namespaced store key used to store jobs that
        # have been parked and should be manually popped later.
        #
        # @param [String] namespace The user-provided store namespace
        #
        # @return [String] The full store cache key
        #
        def store_cache_key(namespace)
          cache_key([Config::WORKER_STORE_PREFIX, namespace])
        end

        #
        # Push the worker to a namespaced store.
        #
        # @param [String] namespace The store namespace
        # @param [Array<any>] *args List of worker arguments
        #
        # @return [String] The number of elements added to the store
        #
        def push_to_store(namespace, *args)
          redis.rpush(store_cache_key(namespace), [args.to_json])
        end

        #
        # Push many workers to a namespaced store at once.
        #
        # @param [String] namespace The store namespace
        # @param [Array<Array<any>>] args_list A list of arguments for each worker
        #
        # @return [String] The number of elements added to the store
        #
        def push_many_to_store(namespace, args_list)
          redis.rpush(store_cache_key(namespace), args_list.map(&:to_json))
        end

        #
        # Pull the jobs from the namespaced store and enqueue them.
        #
        # @param [String] namespace The store namespace.
        # @param [Integer] page_size The number of items to pull on each page. Defaults to 1000.
        #
        def pull_all_from_store(namespace, page_size: 1000)
          items = nil

          while items.nil? || items.present?
            # Pull items
            items = redis.lpop(store_cache_key(namespace), page_size).to_a

            # For each item, execute block or enqueue it
            items.each do |args_json|
              worker_args = JSON.parse(args_json)

              if block_given?
                yield(worker_args)
              else
                perform_async(*worker_args)
              end
            end
          end
        end
      end
    end
  end
end
