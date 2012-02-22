require "railsthemes/version"

module Railsthemes
  def self.install *args
    if args[0] == '--file'
      if args[1]
        read_from_file args[1]
      else
        log_and_abort "The parameter --file means we need another parameter after it to specify what file to load from."
      end
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

  def self.read_from_file filepath
  end

  def self.download_from_hash hash
  end
end
