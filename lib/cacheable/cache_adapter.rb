# frozen_string_literal: true

module Cacheable
  module CacheAdapter
    CACHE_ADAPTER_METHODS = %i[fetch delete].freeze
    DEFAULT_ADAPTER = :memory

    def self.extended(base)
      base.instance_variable_set(:@_cache_adapter, nil)
      base.cache_adapter = DEFAULT_ADAPTER
    end

    def cache_adapter
      @_cache_adapter
    end

    def cache_adapter=(name_or_adapter)
      @_cache_adapter = interprete_adapter(name_or_adapter)
    end

    private

    def interprete_adapter(name_or_adapter)
      return name_or_adapter if cache_adapter?(name_or_adapter)

      unless [Symbol, String].include?(name_or_adapter.class)
        raise ArgumentError, 'Must pass the name of a known adapter or an instance'
      end

      Cacheable::CacheAdapters.lookup(name_or_adapter).new
    end

    def cache_adapter?(adapter_instance)
      CACHE_ADAPTER_METHODS.all? { |method| adapter_instance.respond_to?(method) }
    end
  end
end
