require "railsthemes/version"

module Railsthemes
  def self.install *args
    if args[0] == '--file'
      read_from_file args[1]
    else
      download_from_hash args[0]
    end
  end

  def self.read_from_file filepath
    # TODO
  end

  def self.download_from_hash hash
    # TODO
  end
end
