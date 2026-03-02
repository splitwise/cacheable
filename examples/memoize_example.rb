require 'cacheable' # this may not be necessary depending on your autoloading system

# Wrap the default adapter to log cache reads
logging_adapter = Cacheable::CacheAdapters::MemoryAdapter.new
original_fetch = logging_adapter.method(:fetch)
logging_adapter.define_singleton_method(:fetch) do |key, *args, &block|
  puts "  [cache] fetch #{key.inspect}"
  original_fetch.call(key, *args, &block)
end

Cacheable.cache_adapter = logging_adapter

class ExpensiveService
  include Cacheable

  cacheable :without_memoize

  cacheable :with_memoize, memoize: true

  def without_memoize
    puts '  [method] computing value'
    42
  end

  def with_memoize
    puts '  [method] computing value'
    42
  end
end

svc = ExpensiveService.new

puts '--- without memoize ---'
2.times { svc.without_memoize }
# --- without memoize ---
#   [cache] fetch ["ExpensiveService", :without_memoize]
#   [method] computing value
#   [cache] fetch ["ExpensiveService", :without_memoize]    <-- adapter hit again (deserialization cost)

puts
puts '--- with memoize: true ---'
2.times { svc.with_memoize }
# --- with memoize: true ---
#   [cache] fetch ["ExpensiveService", :with_memoize]
#   [method] computing value
#                                                            <-- no adapter hit, returned from instance memo

puts
puts '--- after clearing ---'
svc.clear_with_memoize_cache
svc.with_memoize
# --- after clearing ---
#   [cache] fetch ["ExpensiveService", :with_memoize]
#   [method] computing value
