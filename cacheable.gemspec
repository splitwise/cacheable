# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'cacheable/version'

Gem::Specification.new do |s|
  s.name        = 'cacheable'
  s.version     = Cacheable::VERSION
  s.summary     = 'Add caching to any Ruby method in a aspect orientated programming approach.'
  s.description = 'Add caching simply without modifying your existing code. '\
                  'Includes configurable options for simple cache invalidation. '\
                  'See README on github for more information.'
  s.authors     = ['Jess Hottenstein', 'Ryan Laughlin', 'Aaron Rosenberg']
  s.email       = 'support@splitwise.com'
  s.files       = Dir['lib/**/*', 'README.md', 'cache-adapters.md']
  s.homepage    = 'https://github.com/splitwise/cacheable'
  s.licenses    = 'MIT'
  s.required_ruby_version = '>= 2.5.0'
  s.metadata = {'rubygems_mfa_required' => 'true'}
end
