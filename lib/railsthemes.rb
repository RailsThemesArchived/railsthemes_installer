require "railsthemes/version"

module Railsthemes

  def self.execute args
    if args[0] == 'install'
      Railsthemes.install args[1..-1]
    else
      Railsthemes.print_usage
    end
  end

  def self.install *args
    if args[0] == '--file'
      if args[1]
        read_from_file_system args[1]
      else
        print_usage
        log_and_abort "The parameter --file means we need another parameter after it to specify what file to load from."
      end
    elsif args[0] == '--help'
      print_usage
    else
      if args[0]
        download_from_hash args[0]
      else
        log_and_abort "railsthemes expects the hash that you got from the website as a parameter in order to download the theme you bought."
      end
    end
  end

  def self.log_and_abort s
    abort s
  end

  def self.print_usage
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

  def self.read_from_file_system filepath
    if File.directory?(filepath)
      Dir.entries(filepath).each do |entry|
        next if entry == '.' || entry == '..'
        copy_with_replacement File.join(filepath, entry)
      end
    end
  end

  def self.copy_with_replacement filepath
  end

  def self.download_from_hash hash
  end
end
