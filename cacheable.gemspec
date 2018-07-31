# -*- encoding: utf-8 -*-
# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("../lib", __FILE__)
require 'cacheable/version'

Gem::Specification.new do |s|
  s.name        = 'cacheable'
  s.version     = Cacheable::VERSION
  s.date        = '2018-07-31'
  s.summary     = 'Add caching to any Ruby method in a aspect orientated programming approach.'
  s.description = 'Add caching simply without modifying your existing code. Inlcudes configurable options for simple cache invalidation. See README on github for more information.'
  s.authors     = ['Jess Hottenstein', 'Ryan Laughlin', 'Aaron Rosenberg']
  s.email       = 'support@splitwise.com'
  s.files       = Dir['lib/**/*', 'README.md', 'cache-adapters.md']
  s.homepage    = 'https://github.com/splitwise/cacheable'
  s.licenses    = 'MIT'
  s.required_ruby_version = '>= 2.0.0'
end
