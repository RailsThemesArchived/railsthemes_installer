require 'rubygems'
require 'bundler'
require 'logger'
require 'fileutils'
require 'open-uri'
require 'net/http'
require 'rest-client'
require 'launchy'
require 'json'
require 'railsthemes/version'
require 'railsthemes/logging'
require 'railsthemes/safe'
require 'railsthemes/utils'
require 'railsthemes/tar'
require 'railsthemes/installer'
require 'railsthemes/theme_installer'
require 'railsthemes/email_installer'
require 'railsthemes/ensurer'

module Railsthemes
  def self.server
    @server ||= 'https://railsthemes.com'
  end

  def self.server= server
    Logging.logger.warn "Using server: #{server}"
    @server = server
  end
end
