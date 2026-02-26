# frozen_string_literal: true

module Cacheable
  module MethodGenerator
    def cacheable(*original_method_names, **opts)
      original_method_names.each do |original_method_name|
        create_cacheable_methods(original_method_name, opts)
      end
    end

    private

    def method_interceptor_module_name
      class_name = name&.gsub(':', '') || to_s.gsub(/[^a-zA-Z_0-9]/, '')
      "#{class_name}Cacher"
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def create_cacheable_methods(original_method_name, opts = {})
      method_names = create_method_names(original_method_name)
      key_format_proc = opts[:key_format] || default_key_format

      unless_proc = opts[:unless].is_a?(Symbol) ? opts[:unless].to_proc : opts[:unless]

      const_get(method_interceptor_module_name).class_eval do
        define_method(method_names[:key_format_method_name]) do |*args, **kwargs|
          key_format_proc.call(self, original_method_name, args, **kwargs)
        end

        define_method(method_names[:clear_cache_method_name]) do |*args, **kwargs|
          Cacheable.cache_adapter.delete(__send__(method_names[:key_format_method_name], *args, **kwargs))
        end

        define_method(method_names[:without_cache_method_name]) do |*args, **kwargs, &block|
          method(original_method_name).super_method.call(*args, **kwargs, &block)
        end

        define_method(method_names[:with_cache_method_name]) do |*args, **kwargs, &block|
          Cacheable.cache_adapter.fetch(__send__(method_names[:key_format_method_name], *args, **kwargs), opts[:cache_options]) do # rubocop:disable Lint/UselessDefaultValueArgument -- not Hash#fetch; second arg is cache options (e.g. expires_in) passed to the adapter
            __send__(method_names[:without_cache_method_name], *args, **kwargs, &block)
          end
        end

        define_method(original_method_name) do |*args, **kwargs, &block|
          if unless_proc&.call(self, original_method_name, args, **kwargs)
            __send__(method_names[:without_cache_method_name], *args, **kwargs, &block)
          else
            __send__(method_names[:with_cache_method_name], *args, **kwargs, &block)
          end
        end
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def default_key_format
      warned = false

      proc do |target, method_name, method_args, **kwargs|
        if !warned && (!method_args.empty? || !kwargs.empty?)
          warn "Cacheable WARNING: '#{method_name}' is using the default key format but was called with " \
               'arguments. Arguments are NOT included in the cache key, so different arguments will return ' \
               'the same cached value. Provide a :key_format proc to include arguments in the cache key.'
          warned = true
        end

        class_name = (target.is_a?(Module) ? target.name : target.class.name)
        cache_key = target.respond_to?(:cache_key) ? target.cache_key : class_name
        [cache_key, method_name].compact
      end
    end

    def create_method_names(original_method_name)
      method_name_without_punctuation = original_method_name.to_s.sub(/([?!=])$/, '')
      punctuation = Regexp.last_match(-1)

      {
        with_cache_method_name: "#{method_name_without_punctuation}_with_cache#{punctuation}",
        without_cache_method_name: "#{method_name_without_punctuation}_without_cache#{punctuation}",
        key_format_method_name: "#{method_name_without_punctuation}_key_format#{punctuation}",
        clear_cache_method_name: "clear_#{method_name_without_punctuation}_cache#{punctuation}"
      }
    end
  end
end
