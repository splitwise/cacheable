# frozen_string_literal: true

require 'monitor'

module Cacheable
  module CacheAdapters
    class MemoryAdapter
      def initialize
        @monitor = Monitor.new
        clear
      end

      def read(key)
        @monitor.synchronize { @cache[key] }
      end

      def write(key, value)
        @monitor.synchronize { @cache[key] = value }
      end

      def exist?(key)
        @monitor.synchronize { @cache.key?(key) }
      end

      # NOTE: yield is intentionally called inside the lock to prevent thundering herd — only one thread
      # computes a missing value while others wait. This is acceptable for a simple in-memory adapter;
      # production use cases needing high concurrency should use a real cache backend via CacheAdapter.
      def fetch(key, _options = {})
        @monitor.synchronize do
          return @cache[key] if @cache.key?(key)

          @cache[key] = yield
        end
      end

      def delete(key)
        @monitor.synchronize do
          return false unless @cache.key?(key)

          @cache.delete(key)
          true
        end
      end

      def clear
        @monitor.synchronize { @cache = {} }
      end
    end
  end
end
