require 'fileutils'
require 'tmpdir'

# a bunch of things that should never be called in testing due to side effects
module Railsthemes
  class Safe
    def self.verify_not_testing
      raise 'should not call this in test environment' if defined?(TESTING)
    end

    def self.system_call s
      verify_not_testing
      `#{s}`
    end

    def self.log_and_abort s
      verify_not_testing
      abort s
    end

    def self.make_directory filepath
      verify_not_testing
      Dir.mkdir filepath
    end

    def self.directory_entries_for filepath
      verify_not_testing
      Dir.entries filepath
    end

    def self.rename_file src, dest
      verify_not_testing
      File.rename src, dest
    end

    def self.remove_directory dirpath
      verify_not_testing
      FileUtils.rm_rf dirpath
    end

    def self.remove_file filepath
      verify_not_testing
      if File.exists?(filepath)
        File.delete filepath
      end
    end

    def self.copy_file src, dest
      verify_not_testing
      FileUtils.mkdir_p(File.dirname(dest)) # create directory if necessary
      FileUtils.cp src, dest
    end

    def self.directory? filepath
      verify_not_testing
      File.directory? filepath
    end

    def self.file_exists? filepath
      verify_not_testing
      File.exists? filepath
    end

    def self.print_usage
      verify_not_testing
      puts <<-EOS
Usage:
------
railsthemes install HASH
  install a theme from the railsthemes website

railsthemes install --help
  this message

railsthemes install --file filepath
  install from the local filesystem
      EOS
    end

    def self.print_post_installation_instructions
      verify_not_testing
      puts <<-EOS
Your theme is installed!

Make sure that you restart your server if it's currently running.
      EOS
    end

    def self.print_usage_and_abort s
      print_usage
      log_and_abort s
    end
  end
end
