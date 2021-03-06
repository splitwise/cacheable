# frozen_string_literal: true

module Cacheable
  module VERSION
    MAJOR = 1
    MINOR = 0
    TINY = 4
    PRE = nil

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.').freeze

    def self.to_s
      STRING
    end
  end
end
