require 'rubygems'
require 'date'
require 'fileutils'
require 'logger'
require 'tmpdir'
require 'bundler'
require 'net/http'
require 'rest-client'

module Railsthemes
  class Installer
    def initialize logger = nil
      @logger = logger
      @server = 'https://railsthemes.com'
      if File.exist?('railsthemes_server')
        @server = File.read('railsthemes_server').gsub("\n", '')
      end
      @logger ||= Logger.new(STDOUT)
      # just print out basic information, not all of the extra logger stuff
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "#{msg}\n"
      end
      @doc_popup = true
    end

    def doc_popup= doc_popup
      @doc_popup = doc_popup
    end

    def ensure_in_rails_root
      unless File.directory?('app') && File.directory?('public')
        Safe.log_and_abort 'Must be in the Rails root directory to use this gem.'
      end
    end

    def install_from_file_system source_filepath
      if File.directory?(source_filepath)
        ensure_in_rails_root

        @logger.info 'Installing...'

        # this file causes issues when HAML is also present, and we overwrite
        # it in the ERB case, so safe to delete here
        Utils.remove_file('app/views/layouts/application.html.erb')

        Dir["#{source_filepath}/base/**/*"].each do |src|
          dest = src.sub("#{source_filepath}/base/", '')
          if File.directory?(src)
            FileUtils.mkdir_p(dest)
          else
            unless dest =~ /railsthemes_.*_overrides\.*/ && File.exists?(dest)
              FileUtils.cp(src, dest)
            end
          end
        end
        gem_names = gemspecs(Utils.read_file('Gemfile.lock')).map(&:name) - ['haml', 'sass']
        install_gems_from(source_filepath, gem_names)

        @logger.info 'Done installing.'
        post_copying_changes
        print_post_installation_instructions
        popup_documentation if @doc_popup
      elsif archive?(source_filepath)
        if File.exists?(source_filepath)
          install_from_archive source_filepath
          # no need for post_installation, because we will do this in the
          # install_from_archive method
        else
          Safe.log_and_abort 'Cannot find the file you specified.'
        end
      else
        print_usage_and_abort 'Need to specify either a directory or an archive file when --file is used.'
      end
    end

    def popup_documentation
      style_guide = Dir['doc/*Usage_And_Style_Guide.html'].first
      Safe.system_call("open #{style_guide}") if style_guide
    end

    def install_gems_from source_filepath, gem_names
      gems_that_we_can_install = Dir.entries("#{source_filepath}/gems").reject{|x| x == '.' || x == '..'}
      (gem_names & gems_that_we_can_install).each do |gem_name|
        FileUtils.cp_r(File.join(source_filepath, 'gems', gem_name, '.'), '.')
      end
    end

    def install_from_archive filepath
      @logger.info "Extracting..."
      with_tempdir do |tempdir|
        Safe.system_call untar_string(filepath, tempdir)
        # remove any pesky hidden files that crept into the archivej
        Dir["#{tempdir}/**/.*"].reject {|x| x =~ /\/\.\.?$/}.each do |file|
          File.unlink(file)
        end
        @logger.info "Finished extracting."
        install_from_file_system tempdir
      end
    end

    def download_from_code code
      vcs_is_unclean_message = check_vcs_status
      if vcs_is_unclean_message
        Safe.log_and_abort vcs_is_unclean_message
      else
        version_is_bad_message = check_installer_version
        if version_is_bad_message
          Safe.log_and_abort version_is_bad_message
        else
          if File.exists?('Gemfile.lock') && Gem::Version.new('3.1') <= rails_version
            install_from_server code
          else
            ask_to_install_unsupported code
          end
        end
      end
    end

    def check_installer_version
      begin
        response = Utils.get_url(@server + '/installer/version')
      rescue SocketError => e
        Safe.log_and_abort 'We could not reach the RailsThemes server to download the theme. Please check your internet connection and try again.'
      rescue Exception => e
        #@logger.info e.message
        #@logger.info e.backtrace
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
        end
      else
        'There was an issue checking your installer version.'
      end
    end

    def install_from_server code
      @logger.info "Downloading theme from server..."
      with_tempdir do |tempdir|
        archive = File.join(tempdir, 'archive.tar.gz')
        if File.exists?('Gemfile.lock')
          send_gemfile code # first time hitting the server
        end
        config = get_primary_configuration(Utils.read_file('Gemfile.lock'))
        dl_url = get_download_url "#{@server}/download?code=#{code}&config=#{config}"
        if dl_url
          Utils.download_file_to dl_url, archive
          @logger.info "Finished downloading."
          install_from_archive archive
        else
          Safe.log_and_abort("We didn't recognize the code you gave to download the theme (#{code}). It should look something like your@email.com:ABCDEF.")
        end
      end
    end

    def ask_to_install_unsupported code
      @logger.info "WARNING\n"

      if File.exists?('Gemfile.lock')
        @logger.info <<-EOS
Your Gemfile.lock file indicates that you are using a version of Rails that
is not officially supported by RailsThemes.
        EOS
      else
        @logger.info <<-EOS
We could not find a Gemfile.lock file in this directory. This could indicate
that you are not in a Rails application, or that you are not using Bundler
(which probably means that you are using a version of Rails that is not
officially supported by RailsThemes.)
        EOS
      end
      @logger.info <<-EOS
While Rails applications that are less than version 3.1 are not officially
supported, you can try installing anyway, or can stop. If you cancel the
install before downloading, we can refund your purchase. If you install,
we cannot guarantee that RailsThemes will work for your app. You may have
to do some custom changes, which might be as easy as copying files,
but which may be more complicated.
      EOS

      if Safe.yes? 'Do you still wish to install the theme? [y/N]'
        install_from_server code
      else
        Safe.log_and_abort 'Halting.'
      end
    end

    def get_download_url server_request_url
      response = nil
      begin
        response = Utils.get_url server_request_url
      rescue SocketError => e
        Safe.log_and_abort 'We could not reach the RailsThemes server to download the theme. Please check your internet connection and try again.'
      rescue Exception => e
        #@logger.info e.message
        #@logger.info e.backtrace
      end

      if response && response.code.to_s == '200'
        response.body
      else
        nil
      end
    end

    def gemspecs gemfile_contents = nil
      gemfile_contents ||= Utils.read_file('Gemfile.lock')
      return [] if gemfile_contents.strip == ''
      lockfile = Bundler::LockfileParser.new(gemfile_contents)
      lockfile.specs
    end

    def get_primary_configuration gemfile_contents
      gem_names = gemspecs(gemfile_contents).map(&:name)
      (gem_names.include?('haml') ? 'haml' : 'erb') + ',' +
      (gem_names.include?('sass') ? 'scss' : 'css')
    end

    def rails_version gemfile_contents = nil
      gemfile_contents ||= Utils.read_file('Gemfile.lock')
      specs = gemspecs(gemfile_contents)
      rails = specs.select{ |x| x.name == 'rails' }.first
      if rails && rails.version
        rails.version
      end
    end

    def send_gemfile code
      begin
        response = RestClient.post("#{@server}/gemfiles/parse",
          :code => code, :gemfile_lock => File.new('Gemfile.lock', 'rb'))
      rescue SocketError => e
        Safe.log_and_abort 'We could not reach the RailsThemes server to start your download. Please check your internet connection and try again.'
      rescue Exception => e
        @logger.info e.message
        @logger.info e.backtrace
      end
    end

    def with_tempdir &block
      tempdir = generate_tempdir_name
      FileUtils.mkdir_p tempdir
      yield tempdir
      FileUtils.rm_rf tempdir
    end

    def generate_tempdir_name
      File.join(Dir.tmpdir, DateTime.now.strftime("railsthemes-%Y%m%d-%H%M%S-#{rand(100000000)}"))
    end

    def archive? filepath
      filepath =~ /\.tar\.gz$/
    end

    def untar_string filepath, newdirpath
      "tar -zxf #{filepath} -C #{newdirpath}"
    end


    # this happens after a successful copy so that we set up the environment correctly
    # for people to view the theme correctly
    def post_copying_changes
      Utils.remove_file File.join('public', 'index.html')
      create_railsthemes_demo_pages
    end

    def create_railsthemes_demo_pages
      @logger.info 'Creating RailsThemes demo pages...'

      FileUtils.mkdir_p(File.join('app', 'controllers'))
      File.open(File.join('app', 'controllers', 'railsthemes_controller.rb'), 'w') do |f|
        f.write <<-EOS
class RailsthemesController < ApplicationController
  # normally every view will use your application layout
  def inner
    render :layout => 'application'
  end

  # this is a special layout for landing and home pages
  def landing
    render :layout => 'landing'
  end
end
        EOS
      end

      lines = []
      if File.exists?(File.join('config', 'routes.rb'))
        lines = Utils.read_file('config/routes.rb').split("\n")
        last = lines.pop
        if lines.grep(/railsthemes#landing/).empty?
          lines << "  match 'railsthemes/landing' => 'railsthemes#landing'"
        end
        if lines.grep(/railsthemes#inner/).empty?
          lines << "  match 'railsthemes/inner' => 'railsthemes#inner'"
        end
        if lines.grep(/railsthemes#jquery_ui/).empty? 
          lines << "  match 'railsthemes/jquery_ui' => 'railsthemes#jquery_ui'"
        end
        lines << last
        File.open(File.join('config', 'routes.rb'), 'w') do |f|
          lines.each do |line|
            f.puts line
          end
        end
      end

      @logger.info 'Done creating RailsThemes demo pages.'
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
      @logger.info <<-EOS

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

    def print_usage_and_abort s
      Safe.log_and_abort s
    end
  end
end
