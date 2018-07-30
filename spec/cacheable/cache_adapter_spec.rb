require 'spec_helper'

RSpec.describe Cacheable::CacheAdapter do
  subject(:adapter_object) { Class.new { extend(Cacheable::CacheAdapter) } }

  describe '.cache_adapter' do
    it 'returns the instance of the current cache adapter' do
      expect(adapter_object.cache_adapter).to be_instance_of(Cacheable::CacheAdapters::MemoryAdapter)
    end
  end

  describe '.cache_adapter=' do
    context 'when given the name of an adapter' do
      it 'creates an instance of the cache adapter' do
        adapter_object.cache_adapter
        expect(Cacheable::CacheAdapters::MemoryAdapter).to receive(:new)
        adapter_object.cache_adapter = described_class::DEFAULT_ADAPTER
      end

      it 'can also take a string' do
        expect(described_class::DEFAULT_ADAPTER).to be_a(Symbol)

        adapter_object.cache_adapter
        expect(Cacheable::CacheAdapters::MemoryAdapter).to receive(:new)
        adapter_object.cache_adapter = described_class::DEFAULT_ADAPTER.to_s
      end

      it 'errors if there is no adapter for the given name' do
        expect { adapter_object.cache_adapter = :not_real }.to raise_error(NameError, /NotRealAdapter/)
      end
    end

    context 'when given an adapter instance' do
      it 'sets it if the instance conforms to the adapter protocol' do
        memory_adapter = Cacheable::CacheAdapters::MemoryAdapter.new

        expect { adapter_object.cache_adapter = memory_adapter }
          .to change(adapter_object, :cache_adapter).to(memory_adapter)
      end

      it 'raises an Argument error if it does not conform to the protocol' do
        expect { adapter_object.cache_adapter = Object.new }.to raise_error(ArgumentError)
      end
    end
  end
end
