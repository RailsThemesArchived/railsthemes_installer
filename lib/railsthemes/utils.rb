require 'fileutils'

# a bunch of things that should never be called in testing due to side effects
module Railsthemes
  class Utils
    # remove file only if it exists
    def self.remove_file filepath
      if File.exists?(filepath)
        File.delete filepath
      end
    end

    # copy a file, ensuring that the directory is present
    def self.copy_ensuring_directory_exists src, dest
      FileUtils.mkdir_p(File.dirname(dest)) # create directory if necessary
      FileUtils.cp src, dest
    end
  end
end
