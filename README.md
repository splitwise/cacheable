# Cacheable

By [Splitwise](https://www.splitwise.com)

Cacheable is a gem which intends to add method caching in an [aspect-oriented programming (AOP)](https://en.wikipedia.org/wiki/Aspect-oriented_programming) fashion in Ruby. Its core goals are:

* ease of use (method annotation)
* flexibility (simple adaptability for any cache backend)
* portability (plain Ruby for use with any framework)

While Rails is not a requirement, Cacheable was built inside a mature Rails app and later extracted. This first release will seamlessly work in Rails and only includes an adapter for an in-memory cache backed by a simple Hash. This may be enough for your needs but it is more likely that additional cache adapters will need to be written.

See more about [Cache Adapters](cache-adapters.md).

## Getting Started

Add it to your Gemfile:

```ruby
gem 'cacheable'
```

Set your cache adapter

```ruby
# If you're in a Rails app place the following in config/initializers/cacheable.rb
Cacheable.cache_adapter = Rails.cache

# Otherwise you can specify the name of the adapter anywhere before you use it
Cacheable.cache_adapter = :memory
```

### Simple Implementation Example

Cacheable is designed to work seamlessly with your already existing codebase. Consider the following contrived class:

```ruby
class SimpleExample
  def expensive_calculation
    puts 'beginning expensive method'
    …
    return 'my_result'
  end
end
```

To cache this method and it's result, simply add the following:

```ruby
require 'cacheable' # this may not be necessary depending on your autoloading system

class SimpleExample
  include Cacheable

  cacheable :expensive_calculation

  def expensive_calculation
    puts 'beginning expensive method'
    …
    return 'my_result'
  end
end
```

**That's it!** There's some complex Ruby magic going on under the hood but to the end user you can simply call `expensive_calculation` and the result will be retrieved from the cache, if available, or generated and placed into the cache. To confirm it is working, fire up an IRB console try the following:

```irb
> s = SimpleExample.new
> s.expensive_calculation
beginning expensive method
 => "my_result"
> s.expensive_calculation
 => "my_result"

# Notice that the `puts` was not output the 2nd time the method was invoked.
```

### Additional Methods

Cacheable also adds two useful methods to your class.

#### Skip the Cache via `#{method}_without_cache`

The cache can intentionally be skipped by appending `_without_cache` to the method name. This invocation will neither check the cache nor populate it.  It is as if you called the original method and never used Cacheable.

```irb
> s = SimpleExample.new
> s.expensive_calculation_without_cache
beginning expensive method
 => "my_result"
> s.expensive_calculation_without_cache
beginning expensive method
 => "my_result"
 ```

#### Remove the Value via `clear_#{method}_cache`

The cached value can be cleared at any time by calling `clear_#{your_method_name}_cache`.

```irb
> s = SimpleExample.new
> s.expensive_calculation
beginning expensive method
 => "my_result"
> s.expensive_calculation
 => "my_result"

> s.clear_expensive_calculation_cache
 => true
> s.expensive_calculation
beginning expensive method
 => "my_result"
```

## Additional Configuration

### Cache Invalidation

#### Default

One of the hardest things to do correctly is cache invalidation. Cacheable handles this in a variety of ways. By default Cacheable will construct key a key in the format `[cache_key || class_name, method_name]`.

If the object responds to `cache_key` its return value will be the first element in the array. `ActiveRecord` provides [`cache_key`](https://api.rubyonrails.org/classes/ActiveRecord/Integration.html#method-i-cache_key) but it can be added to any Ruby object or overwritten. If the object does not respond to it, the name of the class will be used instead. The second element will be the name of the method as a symbol.

It is up to the cache adapter what to do with this array. For example, Rails will turn `[SomeClass, :some_method]` into `"SomeClass/some_method"`. For more information see the documentation on [Cache Adapters](cache-adapters.md)

#### Set Your Own

If (re)defining `cache_key` does not provide enough flexibility you can pass a proc to the `key_format:` option of `cacheable`.

```ruby
class CustomKeyExample
  include Cacheable

  cacheable :my_method, key_format: -> (target, method_name, method_args) do
    args = method_args.collect { |argument| "#{argument.class}::#{argument}" }.join
    "#{method_name} called on #{target} with #{args}"
  end

  def my_method(arg1)
    …
  end
end
```

* `target` is the object the method is being called on (`#<CustomKeyExample:0x0…0>`)
* `method_name` is the name of the method being cached (`:my_method`)
* `method_args` is an array of arguments being passed to the method (`[arg1]`)

So if we called `CustomKeyExample.new.my_method(123)` we would get the cache key

`"my_method called on #<CustomKeyExample:0x0…0> with Integer::123"`.

### Conditional Caching

You can control if a method should be cached by supplying a proc to the `unless:` option which will get the same arguments as `key_format:`. Alternatively this method can be defined on the class and a symbol of the name of the method can be passed. **Note**: When using a symbol, the first argument will not be passed but will be available in the method as `self`. The following example will not cache the value if the first argument to the method is `false`.


```ruby
class ConditionalCachingExample
  include Cacheable

  cacheable :maybe_cache, unless: :should_not_cache?

  def maybe_cache(cache)
    …
  end

  def should_not_cache?(_method_name, method_args)
    method_args.first == false
  end
end
```

### Cache Options

If your cache backend supports options you can pass them as the `cache_options:` option. This will be passed though untouched to the cache's `fetch` method.

```ruby
cacheable :with_options, cache_options: {expires_in: 3_600}
```

### Flexible Options

You can use the same options with multiple cache methods or limit them only to specific methods:

```
cacheable :these, :methods, :share, :options, key_format: key_proc, unless: unless_proc
cacheable :this_method_has_its_own_options, unless: unless_proc2
```

### Class Method Caching

You can cache class methods just as easily as a Ruby class is just an instance of `Class`. You simply need to `include Cacheable` within the `class << self` block. Methods can be defined in this block or outside using the `def self.` syntax.

```ruby
class StaticMethodExample
  class << self
    include Cacheable

    cacheable :class_method, :self_class_method

    def class_method
      puts 'class_method called'
    end
  end

  def self.self_class_method
    puts 'self_class_method called'
  end
end
```

### Contributors (alphabetical by last name)

* [Jess Hottenstein](https://github.com/jhottenstein)
* [Ryan Laughlin](https://github.com/rofreg)
* [Aaron Rosenberg](https://github.com/agrberg)
