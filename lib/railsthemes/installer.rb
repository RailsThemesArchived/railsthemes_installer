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
      @server = File.exist?('railsthemes_server') ? File.read('railsthemes_server') : 'https://railsthemes.com'
      @logger ||= Logger.new(STDOUT)
      # just print out basic information, not all of the extra logger stuff
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "#{msg}\n"
      end
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
        FileUtils.cp_r(File.join(source_filepath, 'base', '.'), '.')
        gemfile_contents = File.read('Gemfile.lock')
        install_gems_from(source_filepath, gems_used(File.read('Gemfile.lock')) - ['haml', 'sass'])

        @logger.info 'Done installing.'
        post_copying_changes
        print_post_installation_instructions
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
        @logger.info "Finished extracting."
        install_from_file_system tempdir
      end
    end

    def download_from_code code
      check_vcs_status
      if File.exists?('Gemfile.lock')
        @logger.info "Downloading..."
        with_tempdir do |tempdir|
          archive = File.join(tempdir, 'archive.tar.gz')
          send_gemfile code
          config = get_primary_configuration(File.read('Gemfile.lock'))
          dl_url = get_download_url "#{@server}/download?code=#{code}&config=#{config}"
          if dl_url
            Utils.download_file_to dl_url, archive
            @logger.info "Finished downloading."
            install_from_archive archive
          else
            Safe.log_and_abort("We didn't understand the code you gave to download the theme (#{code})")
          end
        end
      else
        Safe.log_and_abort("We could not find your Gemfile.lock file.") unless File.exists?('Gemfile.lock')
      end
    end

    def get_download_url server_request_url
      response = nil
      begin
        response = Net::HTTP.get_response URI.parse(server_request_url)
      rescue Exception => e
        #@logger.info e.message
        #@logger.info e.backtrace
      end

      response.body if response && response.code.to_s == '200'
    end

    def gems_used
      gems_used File.read('Gemfile.lock')
    end

    def gems_used contents
      return [] if contents.strip == ''
      lockfile = Bundler::LockfileParser.new(contents)
      lockfile.specs.map(&:name)
    end

    def get_primary_configuration contents
      gems = gems_used(contents)
      to_return = []
      to_return << (gems.include?('haml') ? 'haml' : 'erb')
      to_return << (gems.include?('sass') ? 'scss' : 'css')
      to_return * ','
    end

    def send_gemfile code
      begin
        response = RestClient.post("#{@server}/gemfiles/parse",
          :code => code, :gemfile_lock => File.new('Gemfile.lock', 'rb'))
      rescue Exception => e
        #@logger.info e.message
        #@logger.info e.backtrace
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
      "tar -zxf #{filepath}"
    end


    # this happens after a successful copy so that we set up the environment correctly
    # for people to view the theme correctly
    def post_copying_changes
      Utils.remove_file File.join('public', 'index.html')
      @logger.info 'Analyzing existing project structure...'
      create_railsthemes_controller
    end

    def create_railsthemes_controller
      FileUtils.mkdir_p(File.join('app', 'controllers'))
      File.open(File.join('app', 'controllers', 'railsthemes_controller.rb'), 'w') do |f|
        f.write <<-EOS
class RailsthemesController < ApplicationController
  # normally every view will use your application layout
  def inner
    render :layout => 'application'
  end

  # this is a special layout
  def landing
    render :layout => 'landing'
  end
end
        EOS
      end

      lines = []
      if File.exists?('config/routes.rb')
        lines = File.read('config/routes.rb').split("\n")
        last = lines.pop
        lines << "  match 'railsthemes/landing' => 'railsthemes#landing'"
        lines << "  match 'railsthemes/inner' => 'railsthemes#inner'"
        lines << last
        File.open('config/routes.rb', 'w') do |f|
          lines.each do |line|
            f.puts line
          end
        end
      end
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
        Safe.log_and_abort("\n#{variety} reports that you have the following pending changes:\n#{result}Please stash or commit the changes before proceeding to ensure that you can roll back after installing if you want.")
      end
    end

    def print_post_installation_instructions
      @logger.info <<-EOS

Yay! Your theme is installed!

=============================

What now?
1) Ensure your new application layout file contains everything that you wanted
   from the old one.
2) Restart your development server if it is currently running (the asset pipeline can
   be finnicky.)
3) Check out the samples at:
   http://localhost:3000/railsthemes/landing
   http://localhost:3000/railsthemes/inner
4) Let us know how it went: @railsthemes or team@railsthemes.com
      EOS
    end

    def print_usage_and_abort s
      Safe.log_and_abort s
    end
  end
end
