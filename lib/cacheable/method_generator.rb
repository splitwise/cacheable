# frozen_string_literal: true
require 'english'

module Cacheable
  module MethodGenerator
    def cacheable(*original_method_names, **opts)
      original_method_names.each do |original_method_name|
        create_cacheable_methods(original_method_name, opts)
      end
    end

    private

    def method_interceptor_module_name
      class_name = name || to_s.gsub(/[^a-zA-Z_0-9]/, '')
      "#{class_name}Cacher"
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def create_cacheable_methods(original_method_name, opts = {})
      method_names = create_method_names(original_method_name)
      key_format_proc = opts[:key_format] || default_key_format

      const_get(method_interceptor_module_name).class_eval do
        define_method(method_names[:key_format_method_name]) do |*args|
          key_format_proc.call(self, original_method_name, args)
        end

        define_method(method_names[:clear_cache_method_name]) do |*args|
          Cacheable.cache_adapter.delete(__send__(method_names[:key_format_method_name], *args))
        end

        define_method(method_names[:without_cache_method_name]) do |*args|
          original_method = method(original_method_name).super_method
          original_method.call(*args)
        end

        define_method(method_names[:with_cache_method_name]) do |*args|
          Cacheable.cache_adapter.fetch(__send__(method_names[:key_format_method_name], *args), opts[:cache_options]) do
            __send__(method_names[:without_cache_method_name], *args)
          end
        end

        define_method(original_method_name) do |*args|
          unless_proc = opts[:unless].is_a?(Symbol) ? opts[:unless].to_proc : opts[:unless]

          if unless_proc&.call(self, original_method_name, args)
            __send__(method_names[:without_cache_method_name], *args)
          else
            __send__(method_names[:with_cache_method_name], *args)
          end
        end
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def default_key_format
      proc do |target, method_name, _method_args|
        # By default, we omit the _method_args from the cache key because there is no acceptable default behavior
        class_name = (target.is_a?(Module) ? target.name : target.class.name)
        cache_key = target.respond_to?(:cache_key) ? target.cache_key : class_name
        [cache_key, method_name].compact
      end
    end

    def create_method_names(original_method_name)
      method_name_without_punctuation = original_method_name.to_s.sub(/([?!=])$/, '')
      punctuation = $LAST_PAREN_MATCH

      {
        with_cache_method_name: "#{method_name_without_punctuation}_with_cache#{punctuation}",
        without_cache_method_name: "#{method_name_without_punctuation}_without_cache#{punctuation}",
        key_format_method_name: "#{method_name_without_punctuation}_key_format#{punctuation}",
        clear_cache_method_name: "clear_#{method_name_without_punctuation}_cache#{punctuation}"
      }
    end
  end
end
