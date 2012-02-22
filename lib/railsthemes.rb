require "railsthemes/version"

module Railsthemes
  def self.install *args
    if args[0] == '--file'
      read_from_file args[1]
    end
  end

  def self.read_from_file filepath
    puts 'here'
  end
end
