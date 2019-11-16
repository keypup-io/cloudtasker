# frozen_string_literal: true

module Cloudtasker
  # Manage meta information on workers. This meta stored is intended
  # to be used by middlewares needing to store extra information on the
  # job.
  # The objective of this class is to provide a shared store to middleware
  # while controlling access to its keys by preveenting access the hash directly
  # (e.g. avoid wild merge or replace operations).
  class MetaStore
    #
    # Build a new instance of the class.
    #
    # @param [<Type>] hash The worker meta hash
    #
    def initialize(hash = {})
      @meta = JSON.parse((hash || {}).to_json, symbolize_names: true)
    end

    #
    # Retrieve meta entry.
    #
    # @param [String, Symbol] key The key of the meta entry.
    #
    # @return [Any] The value of the meta entry.
    #
    def get(key)
      @meta[key.to_sym] if key
    end

    #
    # Set meta entry
    #
    # @param [String, Symbol] key The key of the meta entry.
    # @param [Any] val The value of the meta entry.
    #
    # @return [Any] The value set
    #
    def set(key, val)
      @meta[key.to_sym] = val if key
    end

    #
    # Remove a meta information.
    #
    # @param [String, Symbol] key The key of the entry to delete.
    #
    # @return [Any] The value of the deleted key
    #
    def del(key)
      @meta.delete(key.to_sym) if key
    end

    #
    # Return the meta store as Hash.
    #
    # @return [Hash] The meta store as Hash.
    #
    def to_h
      # Deep dup
      JSON.parse(@meta.to_json, symbolize_names: true)
    end

    #
    # Return the meta store as json.
    #
    # @param [Array<any>] *arg The to_json args.
    #
    # @return [String] The meta store as json.
    #
    def to_json(*arg)
      @meta.to_json(*arg)
    end

    #
    # Equality operator.
    #
    # @param [Any] other The object being compared.
    #
    # @return [Boolean] True if the object is equal.
    #
    def ==(other)
      to_json == other.try(:to_json)
    end
  end
end
