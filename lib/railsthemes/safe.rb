require 'fileutils'
require 'rubygems'
require 'bundler'
require 'thor'

# a bunch of things that should never be called in testing due to side effects
module Railsthemes
  class Safe
    def self.system_call s
      `#{s}`
    end

    def self.log_and_abort s
      abort s
    end

    def self.yes? question, color = nil
      Thor::Shell::Basic.new.yes? question, color
    end
  end
end
