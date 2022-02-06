# frozen_string_literal: true

module Cacheable
  module VERSION
    MAJOR = 1
    MINOR = 0
    TINY = 4
    PRE = nil

    def self.to_s
      [MAJOR, MINOR, TINY, PRE].compact.join('.').freeze
    end
  end
end
