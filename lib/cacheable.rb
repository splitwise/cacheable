# frozen_string_literal: true

#--
# Copyright (c) 2017-2018 Splitwise Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'cacheable/cache_adapter'
require 'cacheable/cache_adapters'
require 'cacheable/method_generator'
require 'cacheable/version'

module Cacheable
  extend CacheAdapter

  def self.included(base)
    base.extend(Cacheable::CacheAdapter)
    base.extend(Cacheable::MethodGenerator)

    interceptor_name = base.send(:method_interceptor_module_name)
    interceptor = Module.new
    interceptor.define_singleton_method(:to_s) { interceptor_name }
    interceptor.define_singleton_method(:inspect) { interceptor_name }
    base.instance_variable_set(:@_cacheable_interceptor, interceptor)
    base.prepend interceptor
  end
end
