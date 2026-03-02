# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Cacheable is a Ruby gem by Splitwise that adds method caching via an AOP (Aspect-Oriented Programming) pattern. Include `Cacheable` in a class, annotate methods with `cacheable :method_name`, and results are automatically cached.

## Commands

```bash
# Install dependencies
bundle install

# Run full default task (rubocop + rspec)
bundle exec rake

# Run tests only
bundle exec rspec

# Run a single test file
bundle exec rspec spec/cacheable/cacheable_spec.rb

# Run a single test by line number
bundle exec rspec spec/cacheable/cacheable_spec.rb:45

# Run linter only
bundle exec rubocop

# Auto-fix lint issues
bundle exec rubocop -a

# Watch and auto-run tests/lint on file changes
bundle exec guard
```

## Architecture

The gem uses **module prepending with dynamic method generation** to intercept and cache method calls.

### Core flow

1. **`Cacheable`** (`lib/cacheable.rb`) — The module users include. On `included`, it extends the host class with `MethodGenerator` and creates a unique anonymous interceptor module that gets prepended to the class.

2. **`MethodGenerator`** (`lib/cacheable/method_generator.rb`) — When `cacheable :method_name` is called, this generates five methods on the interceptor module:
   - `method_name` (override) — dispatcher that routes to `with_cache` or `without_cache` based on the `unless:` condition
   - `method_with_cache` — fetch from cache or compute and store
   - `method_without_cache` — bypass cache, call original
   - `method_key_format` — generate the cache key
   - `clear_method_cache` — invalidate the cache entry

3. **`CacheAdapter`** (`lib/cacheable/cache_adapter.rb`) — Protocol for cache backends. Default is `:memory`. Required interface: `fetch(key, options, &block)` and `delete(key)`.

4. **`MemoryAdapter`** (`lib/cacheable/cache_adapters/memory_adapter.rb`) — Built-in hash-backed in-memory cache. Production use typically wires in `Rails.cache` or a custom adapter.

### Key design details

- Each class that includes `Cacheable` gets its own unique interceptor module (created via `Module.new`), which is prepended to the class. This is how `super` chains through to the original method.
- The `unless:` option accepts a proc/symbol that, when truthy, skips caching and calls the original method directly.
- `key_format:` accepts a proc receiving `(target, method_name, args, **kwargs)` for custom cache key generation.

## Style

- Max line length: 120 characters
- Max method length: 25 lines
- Rubocop enforced with `NewCops: enable`
- No frozen string literal comments required
