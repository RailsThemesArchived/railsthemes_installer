require 'fileutils'

# a bunch of things that should never be called in testing due to side effects
module Railsthemes
  class Safe
    def self.system_call s
      `#{s}`
    end

    def self.log_and_abort s
      abort s
    end
  end
end
