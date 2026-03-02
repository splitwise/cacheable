# Architecture

This document explains how Cacheable works internally. After reading it you should be able to trace any method call through the caching layer and know which file to open when something needs to change.

## File Map

```
lib/
├── cacheable.rb                        # Entry point. Defines the Cacheable module and its `included` hook.
├── cacheable/
│   ├── version.rb                      # VERSION constant (MAJOR.MINOR.TINY.PRE)
│   ├── method_generator.rb             # Generates the five interceptor methods per cached method
│   ├── cache_adapter.rb                # Adapter protocol: resolution, assignment, and fallback logic
│   ├── cache_adapters.rb               # Registry that maps adapter names (symbols) to classes
│   └── cache_adapters/
│       └── memory_adapter.rb           # Built-in thread-safe hash-backed cache
spec/
├── spec_helper.rb
├── cacheable/
│   ├── cacheable_spec.rb               # Integration tests for the full caching lifecycle
│   ├── cache_adapter_spec.rb           # Tests for adapter resolution and assignment
│   └── cache_adapters/
│       └── memory_adapter_spec.rb      # Tests for the in-memory cache backend
examples/
├── simple_example.rb                   # Minimal usage
├── custom_key_example.rb              # Custom key_format proc
├── conditional_example.rb             # unless: option
├── class_method_example.rb            # Caching class methods via eigenclass
└── memoize_example.rb                 # memoize: true with a logging adapter wrapper
```

## The Big Idea

Cacheable uses **module prepending** to insert a caching layer in front of your methods. When you write:

```ruby
class Foo
  include Cacheable
  cacheable :bar
  def bar = "hello"
end
```

Ruby's method lookup for `Foo#bar` becomes:

```
Foo instance
  → FooCacher (prepended interceptor module)  # calls cache or original
    → Foo (the class itself)                  # your actual def bar
      → Object / BasicObject
```

The interceptor module sits in front of the class in the ancestor chain, so calling `bar` hits the interceptor first. The interceptor decides whether to serve a cached value or call `super` (your original method).

## What Happens When You `include Cacheable`

**File: `lib/cacheable.rb` — `Cacheable.included(base)`**

Three things happen when a class includes Cacheable:

1. **Extend with `CacheAdapter`** — gives the class `.cache_adapter` and `.cache_adapter=` so it can optionally override the global adapter.
2. **Extend with `MethodGenerator`** — gives the class the `.cacheable` class method used to declare which methods to cache.
3. **Create and prepend an interceptor module** — an anonymous `Module.new` is created, stored as `@_cacheable_interceptor`, and prepended to the class. All generated methods are defined on this module, not on the class itself. The module gets a readable name like `"FooCacher"` via custom `to_s`/`inspect`.

The interceptor is unique per class. If `Foo` and `Bar` both include Cacheable, they each get their own interceptor module with their own generated methods.

## What Happens When You Call `cacheable :method_name`

**File: `lib/cacheable/method_generator.rb` — `MethodGenerator#cacheable`**

This is a class-level method (added via `extend`). It accepts one or more method names and an options hash. For each method name, it calls `create_cacheable_methods`, which defines **five methods** on the interceptor module:

### Generated Methods

Given `cacheable :star_count`, the following are defined on the interceptor:

| Method | Purpose |
|---|---|
| `star_count` | **Dispatcher.** Checks the `unless:` condition. Routes to `_with_cache` or `_without_cache`. |
| `star_count_with_cache` | **Cache path.** Checks memoization, then calls `adapter.fetch(key) { original }`. |
| `star_count_without_cache` | **Bypass path.** Calls `method(:star_count).super_method.call(...)` to skip straight to the original. |
| `star_count_key_format` | **Key generator.** Calls the `key_format:` proc (or the default) to produce a cache key. |
| `clear_star_count_cache` | **Invalidation.** Deletes the key from the adapter (and from the memoization hash if applicable). |

Methods ending in `?`, `!`, or `=` are handled correctly — the punctuation is moved to the end of each generated name (e.g., `valid?` produces `valid_with_cache?`, `clear_valid_cache?`).

### How `_with_cache` Works (the hot path)

```
star_count called
  → dispatcher checks unless: proc
    → star_count_with_cache
      1. Compute cache key via star_count_key_format
      2. If memoize: true, check @_cacheable_memoized[method][key]
         → hit: return immediately (adapter is never touched)
      3. Call adapter.fetch(key, cache_options) { star_count_without_cache(...) }
         → adapter hit: return deserialized value
         → adapter miss: execute the block (original method), adapter stores result
      4. If memoize: true, store result in @_cacheable_memoized[method][key]
      5. Return result
```

### How the Original Method Is Reached

`_without_cache` calls `method(:star_count).super_method.call(...)`. Because the interceptor is prepended, `method(:star_count)` resolves to the interceptor's version, and `.super_method` walks up to the class's own definition. This is how `super` works through the prepend chain.

### The `unless:` Option

The `unless:` option accepts a proc or a symbol (converted to a proc via `.to_proc`). It receives `(target, method_name, args, **kwargs)`. When it returns truthy, the dispatcher routes to `_without_cache`, skipping the cache entirely.

### Default Key Format

When no `key_format:` is provided, the default proc builds `[cache_key || class_name, method_name]`. If the object responds to `cache_key` (as ActiveRecord models do), that value is used; otherwise the class name string is used. Arguments are **not** included — if the method is called with arguments, a one-time warning is printed to stderr.

### The `memoize:` Option

When enabled, a per-instance hash (`@_cacheable_memoized`) stores deserialized values keyed by `[method_name][cache_key]`. This avoids repeated adapter `fetch` calls (and any deserialization cost) for the lifetime of the object. A sentinel value (`Cacheable::MEMOIZE_NOT_SET`) distinguishes "not yet cached" from a memoized `nil` or `false`. Clearing the cache (`clear_*_cache`) also removes the memoized entry.

## Cache Adapter System

### Protocol

**File: `lib/cacheable/cache_adapter.rb` — `CacheAdapter`**

Any object that responds to `fetch(key, options, &block)` and `delete(key)` can be a cache adapter. `Rails.cache` satisfies this out of the box.

### Resolution Order

```
class-level @_cache_adapter  →  Cacheable (global) @_cache_adapter
```

Each class that includes Cacheable can set its own adapter via `self.cache_adapter = ...`. If none is set, it falls back to `Cacheable.cache_adapter` (the global default). The global default is `:memory` unless overridden (e.g., `Cacheable.cache_adapter = Rails.cache`).

### Setting an Adapter

`cache_adapter=` accepts either:

- **A symbol/string** (e.g., `:memory`) — looked up via `CacheAdapters.lookup`, which converts the name to a class (`memory` → `MemoryAdapter`) and calls `.new`.
- **An object instance** — used directly if it responds to `fetch` and `delete`.

### Adapter Registry

**File: `lib/cacheable/cache_adapters.rb` — `CacheAdapters.lookup`**

Converts a snake_case name to a PascalCase class name, appends `"Adapter"`, and does a `const_get` inside the `Cacheable::CacheAdapters` namespace. To add a new built-in adapter, define a class like `Cacheable::CacheAdapters::RedisAdapter` and set it with `Cacheable.cache_adapter = :redis`.

### Memory Adapter

**File: `lib/cacheable/cache_adapters/memory_adapter.rb`**

A `Hash` wrapped in a `Monitor` for thread safety. `fetch` yields inside the lock to prevent thundering herd on cache miss (two threads racing to compute the same value). Intended for testing and simple use cases.

## Class Method Caching

Cacheable works on class methods by including it in the eigenclass:

```ruby
class Foo
  class << self
    include Cacheable
    cacheable :bar
  end
end
```

This prepends an interceptor onto `Foo`'s singleton class. Inside generated methods, `is_a?(Module)` checks distinguish class-level calls (where the "instance" is the class itself) from regular instance calls, so the correct adapter is resolved via `singleton_class` rather than `self.class`.

## Adding a New Feature — Where to Look

| I want to... | File |
|---|---|
| Change what methods are generated | `lib/cacheable/method_generator.rb` — `create_cacheable_methods` |
| Change the default cache key | `lib/cacheable/method_generator.rb` — `default_key_format` |
| Add a new option to `cacheable` | `lib/cacheable/method_generator.rb` — `opts` hash in `create_cacheable_methods` |
| Change how adapters are resolved | `lib/cacheable/cache_adapter.rb` |
| Add a built-in adapter | `lib/cacheable/cache_adapters/` — new file, require it from `cache_adapters.rb` |
| Change the module prepend behavior | `lib/cacheable.rb` — `included` hook |
| Write tests | `spec/cacheable/cacheable_spec.rb` for integration, adapter-specific specs in `spec/cacheable/cache_adapters/` |
