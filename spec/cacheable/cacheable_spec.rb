RSpec.describe Cacheable do
  subject(:cacheable_object) { cacheable_class.new }

  let(:cacheable_method) { :cacheable_method }
  let(:cacheable_method_inner) { :cacheable_method_inner }
  let(:cacheable_class) { Class.new.tap { |klass| klass.class_exec(&class_definition) } }

  let(:class_definition) do
    cacheable_method_name = cacheable_method
    cacheable_method_inner_name = cacheable_method_inner
    proc do
      include Cacheable # rubocop:disable RSpec/DescribedClass

      define_method(cacheable_method_name) do |arg = nil|
        send cacheable_method_inner_name, arg
      end

      define_method(cacheable_method_inner_name) do |arg = nil|
        "a unique value with arg #{arg}"
      end

      cacheable cacheable_method_name
    end
  end

  before { described_class.cache_adapter.clear }

  describe 'basic functionality' do
    it 'returns the expected value' do
      expect(cacheable_object.send(cacheable_method)).to eq(cacheable_object.send(cacheable_method_inner))
    end

    it 'retrieves the value from the cache' do
      expect(cacheable_object).to receive(cacheable_method_inner).once.and_call_original

      2.times { cacheable_object.send(cacheable_method) }
    end

    it 'passes the arguments to the underlying method' do
      arg = 'an argument'
      expect(cacheable_object).to receive(cacheable_method_inner).with(arg)

      cacheable_object.send(cacheable_method, arg)
    end

    it 'creates a method that can skip the cache' do
      expect(cacheable_object).to receive(cacheable_method_inner).twice.and_call_original

      2.times { cacheable_object.send("#{cacheable_method}_without_cache") }
    end

    it 'creates a method that calls the cache' do
      expect(cacheable_object).to receive(cacheable_method_inner).once.and_call_original

      2.times { cacheable_object.send("#{cacheable_method}_with_cache") }
    end

    it 'creates a method that returns the key for that object' do
      expect(cacheable_object.cacheable_method_key_format).to eq([cacheable_method])
    end

    it 'creates a method that will clear the cache' do
      any_other_cached_value = :any_other_cached_value
      described_class.cache_adapter.write(any_other_cached_value, 'for the love of ~~dog~~ cat, do not clear me')
      cacheable_object.send(cacheable_method)

      expect { cacheable_object.send("clear_#{cacheable_method}_cache") }
        .to change { described_class.cache_adapter.read(cacheable_object.cacheable_method_key_format) }.to(nil)
        .and not_change { described_class.cache_adapter.read(any_other_cached_value) } # rubocop:disable Layout/MultilineMethodCallIndentation
    end

    it 'allows access to `super` via a module interceptor' do
      better_string = Class.new(String) do
        include Cacheable

        cacheable def to_s
          "Better #{super}"
        end
      end
      stub_const('BetterString', better_string)

      better_string = BetterString.new('my string')
      expect(better_string).to receive(:to_s_with_cache).twice.and_call_original
      expect(better_string).to receive(:to_s_without_cache).once.and_call_original
      2.times { expect(better_string.to_s).to eq('Better my string') }
    end

    it 'uses the class name to define an interceptor module' do
      # This is done specifically this way to be compatible w/ RSpec best practices
      # Once Cacheable is included in a class, it uses the name of the class to define the
      # interceptor module. However, it is considered bad practice to create constants in RSpec
      # so they're typically made with `stub_const`. We need to include Cacheable after the
      # anonymous class has been created and assigned to the stubbed constant for this order to work.
      stub_const('RealClassName', Class.new)
      class_name = RealClassName.include(described_class)

      expect(class_name.ancestors.map(&:to_s)).to include("Cacheable::#{class_name}Cacher")
    end

    it 'uses the class address to define an interceptor module for anonymous classes' do
      custom_class = Class.new { include Cacheable }
      class_name = custom_class.to_s.tr('#:<>', '')

      expect(custom_class.ancestors.map(&:to_s)).to include("Cacheable::#{class_name}Cacher")
    end

    context 'when the method name has special characters' do
      %w[? ! =].each do |special_character|
        it "appends #{special_character} to the end of generated method names" do
          method_name = "cacheable_method#{special_character}"
          cacheable_class.class_eval do
            cacheable define_method(method_name, -> {})
          end

          expect(cacheable_object).to respond_to("cacheable_method_without_cache#{special_character}")
          expect(cacheable_object).to respond_to("cacheable_method_with_cache#{special_character}")
        end
      end
    end

    context 'when classes are nested' do
      it 'correctly names interceptor modules' do
        stub_const('Outer::Inner', Class.new)
        Outer::Inner.include(described_class)

        expect(Outer::Inner.ancestors.map(&:to_s)).to include('Cacheable::OuterInnerCacher')
      end
    end
  end

  describe 'interceptor module' do
    it 'has the public generated methods' do
      expect(cacheable_class.ancestors.first.instance_methods(false)).to include(cacheable_method, :"#{cacheable_method}_without_cache", :"#{cacheable_method}_with_cache", :"#{cacheable_method}_key_format")
    end
  end

  describe 'cacheable module' do
    it 'has no instance methods' do
      expect(described_class.instance_methods(false)).to be_empty
      expect(described_class.private_instance_methods(false)).to be_empty
    end
  end

  describe 'key generation' do
    context 'without any customization' do
      it 'uses the class name and method name for the cache key' do
        stub_const('TotallyRealClassName', cacheable_class)
        cacheable_object = TotallyRealClassName.new
        key = cacheable_object.cacheable_method_key_format

        expect(key).to eq([cacheable_object.class.name, cacheable_method])
        expect { cacheable_object.cacheable_method }
          .to change { described_class.cache_adapter.exist?(key) }.from(false).to(true)
      end

      it 'does not use the arguments to the method to determine the cache key' do
        args = [1]
        expect(cacheable_object.cacheable_method_key_format(*args)).to eq([cacheable_method])
      end

      it 'uses different keys for different cached values' do
        another_cacheable_method = :another_cacheable_method
        inner_method = cacheable_method_inner
        cacheable_class.class_eval do
          define_method(another_cacheable_method) do |arg|
            send inner_method, arg
          end

          cacheable another_cacheable_method
        end
        arg1 = 'arg1'
        arg2 = 'arg2'

        expect(cacheable_object).to receive(inner_method).with(arg1).once.and_call_original
        expect(cacheable_object).to receive(inner_method).with(arg2).once.and_call_original

        2.times { expect(cacheable_object.send(cacheable_method, arg1)).to include(arg1) }
        2.times { expect(cacheable_object.send(another_cacheable_method, arg2)).to include(arg2) }
      end

      it 'uses the value of `cache_key` if the method is defined instead of the class' do
        cache_key = ['a', 2, false]
        cacheable_object.class.class_eval do
          define_method('cache_key') do
            cache_key
          end
        end

        expect { cacheable_object.send(cacheable_method) }
          .to change { described_class.cache_adapter.exist?([cache_key, cacheable_method]) }.from(false).to(true)
      end
    end

    it 'can accept a custom key format via option' do
      custom_key_cacheable_method = :custom_key_cacheable_method
      custom_cache_key = 'a_key'
      cacheable_class.class_eval do
        define_method(custom_key_cacheable_method) do
          true
        end

        cacheable custom_key_cacheable_method, key_format: proc { custom_cache_key }
      end

      expect { cacheable_object.send(custom_key_cacheable_method) }
        .to change { described_class.cache_adapter.exist?(custom_cache_key) }.from(false).to(true)
    end

    it 'can access the method name and arguments' do
      custom_key_cacheable_method = :custom_key_cacheable_method
      cacheable_class.class_eval do
        define_method(custom_key_cacheable_method) do |*x|
          x
        end

        cacheable custom_key_cacheable_method, key_format: proc { |target, method_name, method_args| [target.class, method_name, method_args] }
      end
      args = [1, 2, 3]
      key = cacheable_object.send("#{custom_key_cacheable_method}_key_format", *args)
      expect { cacheable_object.send(custom_key_cacheable_method, *args) }
        .to change { described_class.cache_adapter.exist?(key) }.from(false).to(true)
    end

    it 'custom key format has access to the object instance' do
      custom_key_object_access_cacheable_method = :custom_key_object_access_cacheable_method
      cacheable_class.class_eval do
        define_method(custom_key_object_access_cacheable_method) do
          true
        end

        attr_accessor :secret

        cacheable custom_key_object_access_cacheable_method, key_format: proc { |c| c.secret }
      end
      cacheable_object.secret = 'some_state_on_the_object'

      expect { cacheable_object.send(custom_key_object_access_cacheable_method) }
        .to change { described_class.cache_adapter.exist?(cacheable_object.secret) }.from(false).to(true)
    end
  end

  describe 'syntactic sugar' do
    it 'allows cacheable to be used before the method is defined' do
      cacheable_called_before_definition = :cacheable_called_before_definition
      inner_method = cacheable_method_inner
      cacheable_class.class_eval do
        cacheable cacheable_called_before_definition

        define_method(cacheable_called_before_definition) do
          send inner_method
        end
      end

      expect(cacheable_object).to receive(inner_method).once.and_call_original
      2.times { cacheable_object.send(cacheable_called_before_definition) }
    end

    describe 'flexible `cacheable` syntax' do
      let(:cache_methods) { %i[one two] }

      before do
        cache_methods.each do |method_name|
          cacheable_class.class_eval do
            define_method(method_name) do
              true
            end
          end
        end
      end

      it 'allows cachable to be called once for a series of methods' do
        local_variable_so_class_eval_works = cache_methods

        cacheable_class.class_eval do
          cacheable(*local_variable_so_class_eval_works)
        end

        expect(described_class.cache_adapter).to receive(:write).twice.and_call_original
        2.times { cache_methods.each { |method| cacheable_object.send(method) } }
      end

      it 'uses the same options for cacheable methods declared on a single line' do
        local_variable_so_class_eval_works = cache_methods

        cacheable_class.class_eval do
          cacheable(*local_variable_so_class_eval_works, unless: proc { true })
        end

        expect(described_class.cache_adapter).not_to receive(:write)
        2.times { cache_methods.each { |method| cacheable_object.send(method) } }
      end

      it 'can take strings' do
        cache_methods_as_strings = cache_methods.map(&:to_s)

        cacheable_class.class_eval do
          cacheable(*cache_methods_as_strings)
        end

        expect(described_class.cache_adapter).to receive(:write).twice.and_call_original
        2.times { cache_methods.each { |method| cacheable_object.send(method) } }
      end

      it 'can take strings before the method is defined' do
        cache_method_string = 'called_before_defined'
        inner_method = cacheable_method_inner

        cacheable_class.class_eval do
          cacheable cache_method_string

          define_method(cache_method_string) do
            send inner_method
          end
        end

        expect(cacheable_object).to receive(inner_method).once.and_call_original
        2.times { cacheable_object.send(cache_method_string) }
      end
    end

    it 'skips the cache if `unless` proc is true' do
      always_skip_cache_method = :always_skip_cache_method
      inner_method = cacheable_method_inner
      cacheable_class.class_eval do
        cacheable always_skip_cache_method, unless: proc { true }

        define_method(always_skip_cache_method) do
          send inner_method
        end
      end

      expect(cacheable_object).to receive(inner_method).twice.and_call_original
      2.times { cacheable_object.send(always_skip_cache_method) }
    end
  end

  describe 'conditional caching' do
    it 'skips the cache if `unless` proc is true' do
      always_skip_cache_method = :always_skip_cache_method
      inner_method = cacheable_method_inner
      cacheable_class.class_eval do
        define_method(always_skip_cache_method) do
          send inner_method
        end

        cacheable always_skip_cache_method, unless: proc { true }
      end

      expect(cacheable_object).to receive(inner_method).twice.and_call_original
      2.times { cacheable_object.send(always_skip_cache_method) }
    end

    it 'uses the cache if the `unless` proc is false' do
      always_gets_cached_method = :always_gets_cached_method
      inner_method = cacheable_method_inner
      cacheable_class.class_eval do
        define_method(always_gets_cached_method) do
          send inner_method
        end

        cacheable always_gets_cached_method, unless: proc { false }
      end

      expect(cacheable_object).to receive(inner_method).once.and_call_original
      2.times { cacheable_object.send(always_gets_cached_method) }
    end

    it 'can use a symbol of an instance method instead of a proc for `unless`' do
      symbol_unless_cache_method = :symbol_unless_cache_method
      inner_method = cacheable_method_inner
      cacheable_class.class_eval do
        define_method(symbol_unless_cache_method) do
          send inner_method
        end

        cacheable symbol_unless_cache_method, unless: :cache_control_method

        def cache_control_method(*_args)
          true
        end
      end

      expect(cacheable_object).to receive(inner_method).twice.and_call_original
      2.times { cacheable_object.send(symbol_unless_cache_method) }
    end

    it 'has access to the method receiver - object instance' do
      cache_depends_on_method = :cache_depends_on_method
      inner_method = cacheable_method_inner
      cacheable_class.class_eval do
        define_method(cache_depends_on_method) do
          send inner_method
        end

        def cache_control_method
          'not 12345'
        end

        cacheable cache_depends_on_method, unless: proc { |target, _, _| target.cache_control_method == 12_345 }
      end

      expect(cacheable_object).to receive(inner_method).once.and_call_original
      2.times { cacheable_object.send(cache_depends_on_method) }
    end

    it 'can access the method name' do
      cache_depends_on_method = :cache_depends_on_method
      inner_method = cacheable_method_inner
      cacheable_class.class_eval do
        define_method(cache_depends_on_method) do
          send inner_method
        end

        cacheable cache_depends_on_method, unless: proc { |_, method_name, _| method_name == cache_depends_on_method }
      end
      expect(cacheable_object).to receive(inner_method).twice.and_call_original
      2.times { cacheable_object.send(cache_depends_on_method) }
    end

    it 'can access the method arguments' do
      cache_depends_on_args = :cache_depends_on_args
      the_method_arg = :skip_caching
      inner_method = cacheable_method_inner
      cacheable_class.class_eval do
        define_method(cache_depends_on_args) do |_x|
          send inner_method
        end

        cacheable cache_depends_on_args, unless: proc { |_, _, method_args| method_args.first == the_method_arg }
      end
      expect(cacheable_object).to receive(inner_method).twice.and_call_original
      2.times { cacheable_object.send(cache_depends_on_args, the_method_arg) }
    end
  end

  describe 'on class methods' do
    # Adding class methods in a totally weird way because `class << self` does not allow access to local variables
    let(:cacheable_class) do
      Class.new.tap { |klass| klass.singleton_class.class_exec(&class_definition) }
    end

    it 'uses the class name and method name for the cache key' do
      stub_const('AnotherTotallyRealClassName', cacheable_class)
      key = AnotherTotallyRealClassName.cacheable_method_key_format

      expect(key).to eq([cacheable_class.name, cacheable_method])
    end
  end

  it 'passes `cache_options` to the cache client' do
    cache_options = {expires_in: 3_600}
    cache_method_with_cache_options = :cache_method_with_cache_options
    cacheable_class.class_eval do
      define_method(cache_method_with_cache_options) do
        calculate_hard_value
      end

      cacheable :cache_method_with_cache_options, cache_options: cache_options
    end

    expect(described_class.cache_adapter).to receive(:fetch).with(anything, hash_including(cache_options))
    cacheable_object.send(cache_method_with_cache_options)
  end
end
