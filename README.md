# Cacheable

By [Splitwise](https://www.splitwise.com)

Cacheable is a gem which adds method caching in Ruby following an [aspect-oriented programming (AOP)](https://en.wikipedia.org/wiki/Aspect-oriented_programming) paradigm. Its core goals are:

* ease of use (method annotation)
* flexibility (simple adaptability for any cache backend)
* portability (plain Ruby for use with any framework)

While using Ruby on Rails is not a requirement, Cacheable was built inside a mature Rails app and later extracted. The current release is designed for drop-in support in Rails, and includes an adapter for an in-memory cache backed by a simple hash. This may be enough for your needs, but it's more likely that additional cache adapters will need to be written for other projects.

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

Cacheable is designed to work seamlessly with your already existing codebase. Consider the following example where we fetch the star count for Cacheable from GitHub's API. Feel free to copy/paste it into your IRB console or use the code in `examples/simple_example.rb`.

```ruby
require 'json'
require 'net/http'

class GitHubApiAdapter
  def star_count
    puts "Fetching data from GitHub"
    url = 'https://api.github.com/repos/splitwise/cacheable'

    JSON.parse(Net::HTTP.get(URI.parse(url)))['stargazers_count']
  end
end
```

To cache this method and its result, simply add the following:

```ruby
# From examples/simple_example.rb

require 'cacheable' # this may not be necessary depending on your autoloading system
require 'json'
require 'net/http'

class GitHubApiAdapter
  include Cacheable

  cacheable :star_count

  def star_count
    puts "Fetching data from GitHub"
    url = 'https://api.github.com/repos/splitwise/cacheable'


    JSON.parse(Net::HTTP.get(URI.parse(url)))['stargazers_count']
  end
end
```

**That's it!** There's some complex Ruby magic going on under the hood but to the end user you can simply call `star_count` and the result will be retrieved from the cache, if available, or fetched from the network and placed into the cache. To confirm it is working, fire up an IRB console try the following:

```irb
> a = GitHubApiAdapter.new
> a.star_count
Fetching data from GitHub
 => 2
> a.star_count
 => 2

# Notice that "Fetching data from GitHub" was not output the 2nd time the method was invoked.
# The network call and result parsing would also not be performed again.
```

### Additional Methods

Cacheable also adds two useful methods to your class.

#### Skip the Cache via `#{method}_without_cache`

The cache can intentionally be skipped by appending `_without_cache` to the method name. This invocation will neither check the cache nor populate it.  It is as if you called the original method and never used Cacheable.

```irb
> a = GitHubApiAdapter.new
> a.star_count
Fetching data from GitHub
 => 2
> a.star_count_without_cache
Fetching data from GitHub
 => 2
> a.star_count
 => 2
```

#### Remove the Value via `clear_#{method}_cache`

The cached value can be cleared at any time by calling `clear_#{your_method_name}_cache`.

```irb
> a = GitHubApiAdapter.new
> a.star_count
Fetching data from GitHub
 => 2
> a.star_count
 => 2

> a.clear_star_count_cache
 => true
> a.star_count
Fetching data from GitHub
 => 2
```

## Additional Configuration

### Cache Keys

#### Default

By default, Cacheable will construct key a key in the format `[cache_key || class_name, method_name]` without using method arguments.

If the object responds to `cache_key` its return value will be the first element in the array. `ActiveRecord` provides [`cache_key`](https://api.rubyonrails.org/classes/ActiveRecord/Integration.html#method-i-cache_key) but it can be added to any Ruby object or overwritten. If the object does not respond to it, the name of the class will be used instead. The second element will be the name of the method as a symbol.

It is up to the cache adapter what to do with this array. For example, Rails will turn `[SomeClass, :some_method]` into `"SomeClass/some_method"`. For more information see the documentation on [Cache Adapters](cache-adapters.md)

#### Set Your Own

If (re)defining `cache_key` does not provide enough flexibility, you can pass a proc to the `key_format:` option of `cacheable`.

```ruby
# From examples/custom_key_example.rb

require 'cacheable'
require 'json'
require 'net/http'

class GitHubApiAdapter
  include Cacheable

  cacheable :star_count, key_format: -> (target, method_name, method_args) do
    [target.class, method_name, method_args.first, Time.now.strftime('%Y-%m-%d')].join('/')
  end

  def star_count(repo)
    puts "Fetching data from GitHub for #{repo}"
    url = "https://api.github.com/repos/splitwise/#{repo}"

    JSON.parse(Net::HTTP.get(URI.parse(url)))['stargazers_count']
  end
end
```

* `target` is the object the method is being called on (`#<GitHubApiAdapter:0x0…0>`)
* `method_name` is the name of the method being cached (`:star_count`)
* `method_args` is an array of arguments being passed to the method (`[params]`)

Including the method argument(s) allows you to cache different calls to the same method. Without the arguments in the cache key, a call to `star_count('cacheable')` would populate the cache and `star_count('tokenautocomplete')` would return the number of stars for Cacheable instead of what you want.

In addition, we're including the current date in the cache key so calling this method tomorrow will return an updated value.

```irb
> a = GitHubApiAdapter.new
> a.star_count('cacheable')
Fetching data from GitHub for cacheable
 => 2
> a.star_count('cacheable')
 => 2
> a.star_count('tokenautocomplete')
Fetching data from GitHub for tokenautocomplete
 => 1142
> a.star_count('tokenautocomplete')
 => 1142

 # In this example the follow cache keys are generated:
 # GitHubApiAdapter/star_count/cacheable/2018-09-21
 # GitHubApiAdapter/star_count/tokenautocomplete/2018-09-21
```

### Conditional Caching

You can control if a method should be cached by supplying a proc to the `unless:` option which will get the same arguments as `key_format:`. This logic can be defined in a method on the class and the name of the method as a symbol can be passed as well. **Note**: When using a symbol, the first argument, `target`, will not be passed but will be available as `self`.

```ruby
# From examples/conditional_example.rb

require 'cacheable'
require 'json'
require 'net/http'

class GitHubApiAdapter
  include Cacheable

  cacheable :star_count, unless: :growing_fast?, key_format: -> (target, method_name, method_args) do
    [target.class, method_name, method_args.first].join('/')
  end

  def star_count(repo)
    puts "Fetching data from GitHub for #{repo}"
    url = "https://api.github.com/repos/splitwise/#{repo}"

    JSON.parse(Net::HTTP.get(URI.parse(url)))['stargazers_count']
  end

  def growing_fast?(_method_name, method_args)
    method_args.first == 'cacheable'
  end
end
```

Cacheable is new so we don't want to cache the number of stars it has as we expect it to change quickly.

```irb
> a = GitHubApiAdapter.new
> a.star_count('tokenautocomplete')
Fetching data from GitHub for tokenautocomplete
 => 1142
a.star_count('tokenautocomplete')
 => 1142

> a.star_count('cacheable')
Fetching data from GitHub for cacheable
 => 2
> a.star_count('cacheable')
Fetching data from GitHub for cacheable
 => 2
```

### Cache Options

If your cache backend supports options, you can pass them as the `cache_options:` option. This will be passed through untouched to the cache's `fetch` method.

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

You can cache static (class) methods as well by including Cacheable in your class' [eigenclass](https://en.wikipedia.org/wiki/Metaclass#In_Ruby). This is because all Ruby classes are instances of the `Class` class. Understanding how Ruby's class structure works is powerful and useful, however, further explanation is beyond the scope of this README and not necessary to proceed.

Simply put `include Cacheable` and the `cacheable` directive within a `class << self` block as in the example below. The methods you want to cache can be defined in this block or outside using the `def self.#{method_name}` syntax.

```ruby
# From examples/class_method_example.rb

require 'cacheable'
require 'json'
require 'net/http'

class GitHubApiAdapter
  class << self
    include Cacheable

    cacheable :star_count_for_cacheable, :star_count_for_tokenautocomplete

    def star_count_for_cacheable
      star_count('cacheable')
    end

    private

    def star_count(repo)
      puts "Fetching data from GitHub for #{repo}"
      url = "https://api.github.com/repos/splitwise/#{repo}"

      JSON.parse(Net::HTTP.get(URI.parse(url)))['stargazers_count']
    end
  end

  def self.star_count_for_tokenautocomplete
    star_count('tokenautocomplete')
  end
end
```

```irb
> GitHubApiAdapter.star_count_for_cacheable
Fetching data from GitHub for cacheable
 => 2
> GitHubApiAdapter.star_count_for_cacheable
 => 2

> GitHubApiAdapter.star_count_for_tokenautocomplete
Fetching data from GitHub for tokenautocomplete
 => 1142
> GitHubApiAdapter.star_count_for_tokenautocomplete
 => 1142
```

### Other Notes / Frequently Asked Questions

- Q: How does Cacheable handle cache invalidation?
- A: Cacheable takes Rails' cue and sidesteps the difficult problem of cache invalidation in favor of [key-based expiration](https://signalvnoise.com/posts/3113-how-key-based-cache-expiration-works). As DHH mentions in the blog post, `ActiveRecord`'s `cache_key` uses the `updated_at` timestamp so the cache is recalculated as the object changes. This results in new cache values being calculated, and your cache implementation can be configured to expire least recently used (LRU) values. In other applications, care must be taken to include a mechanism of key-based expiration in the `cache_key` method or [`key_format` proc](#set-your-own) or you risk serving stale data. Alternatively the generated [cache clearing](#remove-the-value-via-clear_method_cache) method can be used to explicitly invalidate the cache.

### Contributors (alphabetical by last name)

* [Jess Hottenstein](https://github.com/jhottenstein)
* [Ryan Laughlin](https://github.com/rofreg)
* [Aaron Rosenberg](https://github.com/agrberg)
