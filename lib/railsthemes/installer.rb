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
        files = files_under(source_filepath)
        @logger.info 'Installing...'
        files.each do |file|
          copy_with_backup source_filepath, file
        end
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
      @logger.info "Downloading..."
      with_tempdir do |tempdir|
        archive = File.join(tempdir, 'archive.tar.gz')
        config = gems_to_use code
        if config
          dl_url = get_download_url "#{@server}/download?code=#{code}&config=#{config * ','}"
          if dl_url
            Utils.download_file_to dl_url, archive
            @logger.info "Finished downloading."
            install_from_archive archive
          else
            Safe.log_and_abort("We didn't understand the code you gave to download the theme (#{code})")
          end
        else
          Safe.log_and_abort("We didn't understand the code you gave to download the theme (#{code}) or had trouble reading your Gemfile.lock file.")
        end
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

    def gems_to_use code
      begin
        response = RestClient.post("#{@server}/gemfiles/parse",
          :code => code, :gemfile_lock => File.new('Gemfile.lock', 'rb'))
        #url = URI.parse("#{@server}/gemfiles/parse")
        #request = Net::HTTP.Post.new url.path
        #request.set_form_data({ :code => code, :gemfile_lock => File.read('Gemfile.lock') }, ';')
        #response = Net::HTTP.new(url.host, url.port).start {|http| http.request(request) }
        #puts 'here!'
      rescue Exception => e
        #puts e.message
        #puts e.backtrace
      end

      if response && response.code.to_s == '200'
        response.body.split(',').map(&:to_sym)
      else
        []
      end
    end

    def files_under filepath
      files = Dir.chdir(filepath) { Dir['**/*'] }
      files.select{|f| !File.directory?(File.join(filepath, f))}
    end

    # to be replaced with Thor copy
    def copy_with_backup base_filepath, entry
      if File.exists?(entry)
        # not sure if I should put in a cp -f here, might be better to toss error
        # so I'm using rename instead
        File.rename entry, "#{entry}.old"
      end
      Utils.copy_ensuring_directory_exists File.join(base_filepath, entry), entry
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
