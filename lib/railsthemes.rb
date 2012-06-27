require 'railsthemes/version'
require 'railsthemes/logging'
require 'railsthemes/safe'
require 'railsthemes/utils'
require 'railsthemes/tar'
require 'railsthemes/installer'
require 'railsthemes/theme_installer'

module Railsthemes
  # recalculates each time, should cache
  def self.server
    @server = 'https://railsthemes.com'
    if File.exist?('railsthemes_server')
      @server = File.read('railsthemes_server').gsub("\n", '')
    end
    @server
  end
end
