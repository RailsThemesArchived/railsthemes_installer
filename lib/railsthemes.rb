require "railsthemes/version"

module Railsthemes
  def self.install *args
    if args[0] == '--file'
      if args[1]
        read_from_file args[1]
      else
        log_and_abort("The parameter --file means we need another parameter after it to specify what file to load from.")
      end
    else
      download_from_hash args[0]
    end
  end

  def self.log_and_abort s
    abort(s)
  end

  def self.read_from_file filepath
  end

  def self.download_from_hash hash
    # TODO
  end
end
