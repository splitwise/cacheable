module Cacheable
  module CacheAdapters
    class MemoryAdapter
      def initialize
        clear
      end

      def read(key)
        cache[key]
      end

      def write(key, value)
        cache[key] = value
      end

      def exist?(key)
        cache.key?(key)
      end

      def fetch(key, _options = {})
        return read(key) if exist?(key)

        write(key, yield)
      end

      def delete(key)
        return false unless exist?(key)

        cache.delete key
        true
      end

      def clear
        @cache = {}
      end

      private

      attr_reader :cache
    end
  end
end
