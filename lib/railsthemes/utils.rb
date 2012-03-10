require 'fileutils'

# a bunch of things that should never be called in testing due to side effects
module Railsthemes
  class Utils
    def self.remove_file filepath
      if File.exists?(filepath)
        File.delete filepath
      end
    end

    def self.copy_with_path src, dest
      FileUtils.mkdir_p(File.dirname(dest)) # create directory if necessary
      FileUtils.cp src, dest
    end
  end
end
