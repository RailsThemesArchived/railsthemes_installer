require 'railsthemes/version'
require 'railsthemes/logging'
require 'railsthemes/safe'
require 'railsthemes/utils'
require 'railsthemes/tar'
require 'railsthemes/installer'
require 'railsthemes/theme_installer'

module Railsthemes
  def self.server
    return @server if @server
    @server = 'https://railsthemes.com'
    @server = File.read('railsthemes_server').gsub("\n", '') if File.exist?('railsthemes_server')
    @server
  end
end
