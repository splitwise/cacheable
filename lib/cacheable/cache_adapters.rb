# frozen_string_literal: true

require 'cacheable/cache_adapters/memory_adapter'

module Cacheable
  module CacheAdapters
    ADAPTER = 'Adapter'

    class << self
      def lookup(adapter_name)
        const_get(class_name_for(adapter_name.to_s) + ADAPTER)
      end

      private

      def class_name_for(string)
        string.split('_').map { |name_part| "#{name_part[0].upcase}#{name_part[1..].downcase}" }.join
      end
    end
  end
end
