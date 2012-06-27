require 'railsthemes/version'
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

  def self.logger
    if @logger
      @logger
    else
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::WARN

      # just print out basic information, not all of the extra logger stuff
      @logger.formatter = proc { |severity, datetime, progname, msg| "#{msg}\n" }
      @logger
    end
  end

  def self.logger= logger
    @logger = logger
  end
end
