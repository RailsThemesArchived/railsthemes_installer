require 'rubygems'
require 'date'
require 'fileutils'
require 'logger'
require 'tmpdir'
require 'bundler'
require 'net/http'
require 'rest-client'
require 'launchy'

module Railsthemes
  class Installer
    include Railsthemes::Logging

    def initialize
      @doc_popup = true
      @theme_installer = ThemeInstaller.new
    end

    def doc_popup= doc_popup
      @doc_popup = doc_popup
    end

    def verbose
      logger.level = Logger::INFO
      logger.info 'In verbose mode.'
    end

    def debug
      logger.level = Logger::DEBUG
      logger.debug 'In debug mode.'
    end

    def ensure_in_rails_root
      unless File.directory?('app') && File.directory?('public')
        Safe.log_and_abort 'Must be in the Rails root directory to use this gem.'
      end
    end

    def popup_documentation
      style_guide = Dir['doc/*Usage_And_Style_Guide.html'].first
      logger.debug("style_guide: #{style_guide}")
      Launchy.open(style_guide) if style_guide
    end

    def install_from_file_system original_source_filepath
      ensure_in_rails_root
      @theme_installer.install_from_file_system original_source_filepath
      print_post_installation_instructions
      popup_documentation if @doc_popup
    end

    def download_from_code code
      logger.warn "Checking version control..."
      vcs_is_unclean_message = check_vcs_status
      logger.warn "Done checking version control."
      if vcs_is_unclean_message
        Safe.log_and_abort vcs_is_unclean_message
      else
        logger.warn "Checking installer version..."
        version_is_bad_message = check_installer_version
        logger.warn "Done checking installer version."
        if version_is_bad_message
          Safe.log_and_abort version_is_bad_message
        else
          if File.exists?('Gemfile.lock') && Gem::Version.new('3.1') <= rails_version
            @theme_installer.install_from_server code
          else
            ask_to_install_unsupported code
          end
        end
      end
    end

    def check_installer_version
      url = Railsthemes.server + '/installer/version'
      logger.debug "installer version url: #{url}"
      begin
        response = Utils.get_url url
      rescue SocketError => e
        logger.info e.message
        logger.info e.backtrace * "\n"
        Safe.log_and_abort 'We could not reach the RailsThemes server to download the theme. Please check your internet connection and try again.'
      rescue Exception => e
        logger.info e.message
        logger.info e.backtrace * "\n"
      end

      if response && response.code.to_s == '200'
        server_recommended_version_string = response.body
        server_recommended_version = Gem::Version.new(server_recommended_version_string)
        local_installer_version = Gem::Version.new(Railsthemes::VERSION)

        if server_recommended_version > local_installer_version
          <<-EOS
          Your version is older than the recommended version.
          Your version: #{Railsthemes::VERSION}
          Recommended version: #{server_recommended_version_string}
          EOS
        else
          logger.debug "server recommended version: #{server_recommended_version_string}"
          nil
        end
      else
        'There was an issue checking your installer version.'
      end
    end

    def ask_to_install_unsupported code
      logger.warn "WARNING\n"

      if File.exists?('Gemfile.lock')
        logger.warn <<-EOS
Your Gemfile.lock file indicates that you are using a version of Rails that
is not officially supported by RailsThemes.
        EOS
      else
        logger.warn <<-EOS
We could not find a Gemfile.lock file in this directory. This could indicate
that you are not in a Rails application, or that you are not using Bundler
(which probably means that you are using a version of Rails that is not
officially supported by RailsThemes.)
        EOS
      end
      logger.warn <<-EOS
While Rails applications that are less than version 3.1 are not officially
supported, you can try installing anyway, or can stop. If you cancel the
install before downloading, we can refund your purchase. If you install,
we cannot guarantee that RailsThemes will work for your app. You may have
to do some custom changes, which might be as easy as copying files,
but which may be more complicated.
      EOS

      if Safe.yes? 'Do you still wish to install the theme? [y/N]'
        @theme_installer.install_from_server code
      else
        Safe.log_and_abort 'Halting.'
      end
    end

    def rails_version gemfile_contents = nil
      gemfile_contents ||= Utils.read_file('Gemfile.lock')
      specs = Utils.gemspecs(gemfile_contents)
      rails = specs.select{ |x| x.name == 'rails' }.first
      rails.version if rails && rails.version
    end

    def check_vcs_status
      result = ''
      variety = ''
      if File.directory?('.git')
        variety = 'Git'
        result = Safe.system_call('git status -s')
      elsif File.directory?('.hg')
        variety = 'Mercurial'
        result = Safe.system_call('hg status')
      elsif File.directory?('.svn')
        variety = 'Subversion'
        result = Safe.system_call('svn status')
      end
      unless result.size == 0
        return "\n#{variety} reports that you have the following pending changes:\n#{result}\nPlease roll back or commit the changes before proceeding to ensure that you can roll back after installing if you want."
      end
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
