require 'rubygems'
require 'date'
require 'fileutils'
require 'logger'
require 'tmpdir'
require 'bundler'
require 'net/http'
require 'rest-client'
require 'launchy'
require 'thor'

module Railsthemes
  class Installer < Thor
    no_tasks do
      include Railsthemes::Logging
      include Thor::Actions

      def initialize
        @doc_popup = true
      end

      def doc_popup= doc_popup
        @doc_popup = doc_popup
      end

      # move to main module
      def verbose
        logger.level = Logger::INFO
        logger.info 'In verbose mode.'
      end

      # move to main module
      def debug
        logger.level = Logger::DEBUG
        logger.debug 'In debug mode.'
      end

      # can probably just make static
      def theme_installer
        @theme_installer ||= ThemeInstaller.new
        @theme_installer
      end

      # can probably just make static
      def email_installer
        @email_installer ||= EmailInstaller.new
        @email_installer
      end

      def popup_documentation
        style_guide = Dir['doc/*Usage_And_Style_Guide.html'].first
        logger.debug("style_guide: #{style_guide}")
        Launchy.open(style_guide) if style_guide
      end

      def install_from_file_system original_source_filepath
        Ensurer.ensure_clean_install_possible

        config = Utils.get_primary_configuration(Utils.read_file('Gemfile.lock'))
        filepath = File.join(original_source_filepath, config.join('-'))
        if File.directory?(filepath)
          theme_installer.install_from_file_system filepath
        elsif File.exists?(filepath + '.tar.gz')
          theme_installer.install_from_file_system filepath + '.tar.gz'
        else
          Safe.log_and_abort "Could not find the file you need: #{filepath}"
        end

        print_post_installation_instructions
        popup_documentation if @doc_popup
      end

      def install_from_code code
        Ensurer.ensure_clean_install_possible
        theme_installer.install_from_server code
        print_post_installation_instructions
        popup_documentation if @doc_popup
      end

      def print_post_installation_instructions
        number = 0
        logger.warn <<-EOS

Yay! Your theme is installed!

=============================

Documentation and help

Theme documentation is located in the doc folder.

There are some help articles for your perusal at http://support.railsthemes.com.


What now?
1) Make sure that you have the jquery-rails gem installed. All of the current
   themes require this in your Gemfile so we can use jQuery UI.
2) Start or restart your development server.
3) Check out the local theme samples at:
   http://localhost:3000/railsthemes/landing
   http://localhost:3000/railsthemes/inner
   http://localhost:3000/railsthemes/jquery_ui
4) Ensure your new application layout file contains everything that you wanted
   from the old one.
5) Let us know how it went: @railsthemes or support@railsthemes.com.
EOS
      end
    end
  end
end
