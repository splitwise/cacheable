require 'cacheable/cache_adapters/memory_adapter'

RSpec.describe Cacheable::CacheAdapters::MemoryAdapter do
  subject(:cache) { described_class.new }

  let(:key) { '_test_cache_key' }

  describe '#fetch' do
    it 'executes the block if the value is not found' do
      flag = false
      expect { cache.fetch(key) { flag = true } }.to change { flag }.from(false).to(true)
    end

    it 'returns the value without running the block if the value is found' do
      cache.fetch(key) { true }
      flag = false
      expect { cache.fetch(key) { flag = true } }.not_to change { flag }.from(false)
    end
  end

  describe '#delete' do
    it 'returns false if the value was not found' do
      expect(cache.delete(key)).to eq(false)
    end

    it 'returns true if the value was found' do
      cache.fetch(key) { true }
      expect(cache.delete(key)).to eq(true)
    end

    it 'removes the value from the cache' do
      cache.fetch(key) { true }
      cache.delete(key)
      flag = false
      expect { cache.fetch(key) { flag = true } }.to change { flag }.from(false).to(true)
    end
  end

  describe '#clear' do
    it 'clears the cache' do
      cache.fetch(key) { true }
      cache.clear
      flag = false
      expect { cache.fetch(key) { flag = true } }.to change { flag }.from(false).to(true)
    end
  end
end
