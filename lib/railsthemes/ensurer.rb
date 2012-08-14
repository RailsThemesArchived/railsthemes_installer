module Railsthemes
  class Ensurer
    extend Railsthemes::Logging

    @@already_checked = false

    # checks if we can cleanly install into the current working directory
    def self.ensure_clean_install_possible options = {}
      return if @@already_checked unless options[:force]
      ensure_in_rails_root
      ensure_bundle_is_up_to_date
      ensure_railsthemes_is_not_in_gemfile
      ensure_vcs_is_clean
      ensure_rails_version_is_valid
      ensure_installer_is_up_to_date unless options[:hit_server] == false
      @@already_checked = true
    end

    def self.ensure_in_rails_root
      unless File.directory?('app') && File.directory?('public')
        Safe.log_and_abort 'Must be in the Rails root directory to use this gem.'
      end
    end

    def self.ensure_vcs_is_clean
      logger.warn "Checking version control..."
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
        Safe.log_and_abort <<-EOS

        #{variety} reports that you have the following pending changes:
        #{result}
Please roll back or commit the changes before proceeding to ensure that you can roll back after installing if you want.
        EOS
      end
      logger.warn "Done checking version control."
    end

    def self.ensure_rails_version_is_valid
      unless File.exists?('Gemfile.lock') && Gem::Version.new('3.1') <= rails_version
        ask_to_install_unsupported
      end
    end

    def self.ensure_installer_is_up_to_date
      logger.warn "Checking installer version..."
      url = Railsthemes.server + '/installer/version'
      logger.debug "installer version url: #{url}"
      begin
        response = Utils.get_url url
      rescue SocketError => e
        logger.debug e.message
        logger.debug e.backtrace * "\n"
        Safe.log_and_abort 'We could not reach the RailsThemes server to download the theme. Please check your internet connection and try again.'
      rescue Exception => e
        logger.debug e.message
        logger.debug e.backtrace * "\n"
      end

      if response && response.code.to_s == '200'
        server_recommended_version_string = response.body
        server_recommended_version = Gem::Version.new(server_recommended_version_string)
        local_installer_version = Gem::Version.new(Railsthemes::VERSION)

        if server_recommended_version > local_installer_version
          Safe.log_and_abort <<-EOS
Your version is older than the recommended version.
Your version: #{Railsthemes::VERSION}
Recommended version: #{server_recommended_version_string}
EOS
        else
          logger.debug "server recommended version: #{server_recommended_version_string}"
        end
      else
        logger.debug 'Got an error'
        logger.debug response
        Safe.log_and_abort 'There was an issue checking your installer version.'
      end
      logger.warn "Done checking installer version."
    end

    def self.ask_to_install_unsupported
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

      unless Safe.yes? 'Do you still wish to install the theme? [y/N]'
        Safe.log_and_abort 'Halting.'
      end
    end

    def self.ensure_bundle_is_up_to_date
      logger.warn "Checking bundle..."
      result = Safe.system_call('bundle check')
      if result !~ /The Gemfile's dependencies are satisfied/
        Safe.log_and_abort <<-EOS
Running `bundle check` resulted in the following issues:
#{result}
Please run `bundle` and try installing again.
EOS
      end
      logger.warn "Done checking bundle."
    end

    def self.rails_version gemfile_contents = nil
      gemfile_contents ||= Utils.read_file('Gemfile.lock')
      specs = Utils.gemspecs(gemfile_contents)
      rails = specs.select{ |x| x.name == 'rails' }.first
      rails.version if rails && rails.version
    end

    def self.ensure_railsthemes_is_not_in_gemfile gemfile_contents = nil
      gemfile_contents ||= Utils.read_file('Gemfile.lock')
      specs = Utils.gemspecs(gemfile_contents)
      if specs.any? { |x| x.name == 'railsthemes' }
        Safe.log_and_abort "You should not install the railsthemes installer in your Gemfile.\nPlease remove and try again."
      end
    end
  end
end
