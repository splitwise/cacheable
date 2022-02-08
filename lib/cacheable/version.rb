# frozen_string_literal: true

module Cacheable
  module VERSION
    MAJOR = 2
    MINOR = 0
    TINY = 0
    PRE = nil

    def self.to_s
      [MAJOR, MINOR, TINY, PRE].compact.join('.').freeze
    end
  end
end
