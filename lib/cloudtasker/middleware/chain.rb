# frozen_string_literal: true

module Cloudtasker
  module Middleware
    # The class below was originally taken from Sidekiq.
    # See: https://github.com/mperham/sidekiq/blob/master/lib/sidekiq/middleware/chain.rb
    #
    # Middleware are callables configured to run before/after a message is processed.
    # Middlewares can be configured to run on the client side (when jobs are pushed
    # to Cloud Tasks) as well as on the server side (when jobs are processed by
    # your application)
    #
    # To add middleware for the client:
    #
    # Cloudtasker.configure do |config|
    #   config.client_middleware do |chain|
    #     chain.add MyClientHook
    #   end
    # end
    #
    # To modify middleware for the server, just call
    # with another block:
    #
    # Cloudtasker.configure do |config|
    #   config.server_middleware do |chain|
    #     chain.add MyServerHook
    #     chain.remove ActiveRecord
    #   end
    # end
    #
    # To insert immediately preceding another entry:
    #
    # Cloudtasker.configure do |config|
    #   config.client_middleware do |chain|
    #     chain.insert_before ActiveRecord, MyClientHook
    #   end
    # end
    #
    # To insert immediately after another entry:
    #
    # Cloudtasker.configure do |config|
    #   config.client_middleware do |chain|
    #     chain.insert_after ActiveRecord, MyClientHook
    #   end
    # end
    #
    # This is an example of a minimal server middleware:
    #
    # class MyServerHook
    #   def call(worker_instance, msg, queue)
    #     puts "Before work"
    #     yield
    #     puts "After work"
    #   end
    # end
    #
    # This is an example of a minimal client middleware, note
    # the method must return the result or the job will not push
    # to Redis:
    #
    # class MyClientHook
    #   def call(worker_class, msg, queue, redis_pool)
    #     puts "Before push"
    #     result = yield
    #     puts "After push"
    #     result
    #   end
    # end
    #
    class Chain
      include Enumerable

      #
      # Build a new middleware chain.
      #
      def initialize
        @entries = nil
        yield self if block_given?
      end

      #
      # Iterate over the list middlewares and execute the block on each item.
      #
      # @param [Proc] &block The block to execute on each item.
      #
      def each(&block)
        entries.each(&block)
      end

      #
      # Return the list of middlewares.
      #
      # @return [Array<Cloudtasker::Middleware::Chain::Entry>] The list of middlewares
      #
      def entries
        @entries ||= []
      end

      #
      # Remove a middleware from the list.
      #
      # @param [Class] klass The middleware class to remove.
      #
      def remove(klass)
        entries.delete_if { |entry| entry.klass == klass }
      end

      #
      # Add a middleware at the end of the list.
      #
      # @param [Class] klass The middleware class to add.
      # @param [Arry<any>] *args The list of arguments to the middleware.
      #
      # @return [Array<Cloudtasker::Middleware::Chain::Entry>] The updated list of middlewares
      #
      def add(klass, *args)
        remove(klass) if exists?(klass)
        entries << Entry.new(klass, *args)
      end

      #
      # Add a middleware at the beginning of the list.
      #
      # @param [Class] klass The middleware class to add.
      # @param [Arry<any>] *args The list of arguments to the middleware.
      #
      # @return [Array<Cloudtasker::Middleware::Chain::Entry>] The updated list of middlewares
      #
      def prepend(klass, *args)
        remove(klass) if exists?(klass)
        entries.insert(0, Entry.new(klass, *args))
      end

      #
      # Add a middleware before another middleware.
      #
      # @param [Class] oldklass The middleware class before which the new middleware should be inserted.
      # @param [Class] newklass The middleware class to insert.
      # @param [Arry<any>] *args The list of arguments for the inserted middleware.
      #
      # @return [Array<Cloudtasker::Middleware::Chain::Entry>] The updated list of middlewares
      #
      def insert_before(oldklass, newklass, *args)
        i = entries.index { |entry| entry.klass == newklass }
        new_entry = i.nil? ? Entry.new(newklass, *args) : entries.delete_at(i)
        i = entries.index { |entry| entry.klass == oldklass } || 0
        entries.insert(i, new_entry)
      end

      #
      # Add a middleware after another middleware.
      #
      # @param [Class] oldklass The middleware class after which the new middleware should be inserted.
      # @param [Class] newklass The middleware class to insert.
      # @param [Arry<any>] *args The list of arguments for the inserted middleware.
      #
      # @return [Array<Cloudtasker::Middleware::Chain::Entry>] The updated list of middlewares
      #
      def insert_after(oldklass, newklass, *args)
        i = entries.index { |entry| entry.klass == newklass }
        new_entry = i.nil? ? Entry.new(newklass, *args) : entries.delete_at(i)
        i = entries.index { |entry| entry.klass == oldklass } || (entries.count - 1)
        entries.insert(i + 1, new_entry)
      end

      #
      # Checks if middleware has been added to the list.
      #
      # @param [Class] klass The middleware class to check.
      #
      # @return [Boolean] Return true if the middleware is in the list.
      #
      def exists?(klass)
        any? { |entry| entry.klass == klass }
      end

      #
      # Checks if the middlware list is empty
      #
      # @return [Boolean] Return true if the middleware list is empty.
      #
      def empty?
        @entries.nil? || @entries.empty?
      end

      #
      # Return a list of instantiated middlewares. Each middleware gets
      # initialize with the args originally passed to `add`, `insert_before` etc.
      #
      # @return [Array<any>] The list of instantiated middlewares.
      #
      def retrieve
        map(&:make_new)
      end

      #
      # Empty the list of middlewares.
      #
      # @return [Array<Cloudtasker::Middleware::Chain::Entry>] The updated list of middlewares
      #
      def clear
        entries.clear
      end

      #
      # Invoke the chain of middlewares.
      #
      # @param [Array<any>] *args The args to pass to each middleware.
      #
      def invoke(*args)
        return yield if empty?

        chain = retrieve.dup
        traverse_chain = lambda do
          if chain.empty?
            yield
          else
            chain.shift.call(*args, &traverse_chain)
          end
        end
        traverse_chain.call
      end
    end

    # Middleware list item.
    class Entry
      attr_reader :klass, :args

      #
      # Build a new entry.
      #
      # @param [Class] klass The middleware class.
      # @param [Array<any>] *args The list of arguments for the middleware.
      #
      def initialize(klass, *args)
        @klass = klass
        @args = args
      end

      #
      # Return an instantiated middleware.
      #
      # @return [Any] The instantiated middleware.
      #
      def make_new
        @klass.new(*@args)
      end
    end
  end
end
