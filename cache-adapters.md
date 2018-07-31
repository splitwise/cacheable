# Cache Adapters

A cache adapter is an object that Cacheable can use as an interface to your system's cache. Cacheable will work out of the box using the object returned by `Rails.cache` as a cache adapter.

The other adapter provided with the library is the [Memory Adapter](lib/cacheable/cache_adapters/memory_adapter.rb). Is a simple memoizing cache used in testing. It is little more than an object that conforms to the protocol and is backed by a Ruby Hash. When writing a new cache adapter it can be used as a template.

### Protocol

There are only two methods the cache adapter protocol requires.

#### `fetch(key, cache_options) { block }`

`fetch` takes a key and options for the cache implementation. If the key is found in the cache the associated value will be returned. If it is not found, the block will be run and the result of the block will be returned and placed in the cache.

**Note**: Unless manually defined by [setting your own key format proc](README.md#set-your-own), `key` will be an *Array*. It is the cache adapter's responsibility to turn this into whatever value your cache backend requires for keys.

#### `delete(key)`

`delete` takes a key and removes it's associated value in the cache. While not currently depended on by Cacheable, it appears the standard is to return `true` if the value was present and removed and `false` if not present to begin with.

#### Additional useful methods

These are additional methods that are very useful to have on a cache adapter but are not depended on by Cacheable. They can be found in the Memory Adapter but they are only used to aid in testing.

* **`read(key)`** read the value for the given key out of the cache or `nil` if the key is not present
* **`write(key, value)`** write a value to the cache under the key
* **`exist?(key)`** `true` if the key exists in the cache, `false` otherwise
* **`clear`** reset the entire cache
