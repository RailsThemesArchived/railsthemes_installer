require 'date'
require 'fileutils'
require 'logger'
require 'tmpdir'
require 'bundler'
require 'net/http'


# TODO:
# check for source control system
# consider changing structure of installer to use separate classes to 
#    handle different installation types
# 
module Railsthemes
  class Installer
    def initialize logger = nil
      @logger = logger
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
      @logger.info "Downloading..."
      with_tempdir do |tempdir|
        archive = File.join(tempdir, 'archive.tar.gz')
        config = gems_to_use # eventually just send Gemfile up
        dl_url = get_download_url "http://railsthemes.dev/download?code=#{code}&config=#{config*','}"
        if dl_url
          Utils.download_file_to dl_url, archive
          @logger.info "Finished downloading."
          install_from_archive archive
        else
          Safe.log_and_abort("We didn't understand the code you gave to download the theme (#{code}).")
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

      if response && response.code == '200'
        return response.body
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


    def gems_to_use
      return [] unless File.exist?('Gemfile.lock')

      @logger.info 'Figuring out what gems you have installed...'

      # inspect Gemfile.lock
      lockfile = Bundler::LockfileParser.new(Bundler.read_file("Gemfile.lock"))
      gems = lockfile.specs.map(&:name)
      if gems.include?('haml')
        [:haml, :scss]
      else
        [:erb, :scss]
      end
    end

    # this happens after a successful copy so that we set up the environment correctly
    # for people to view the theme correctly
    def post_copying_changes
      Utils.remove_file File.join('public', 'index.html')
      @logger.info 'Analyzing existing project structure...'
      create_welcome_controller unless routes_defined?
    end

    def routes_defined?
      Safe.system_call('rake routes').length > 0
    end

    def create_welcome_controller
      Safe.system_call('rails g controller Welcome index')
      lines = []
      if File.exists?('config/routes.rb')
        File.open('config/routes.rb').each do |line|
          if line =~ /  # root :to => 'welcome#index'/
            lines << "  root :to => 'welcome#index'"
          else
            lines << line
          end
        end
        File.open('config/routes.rb', 'w') do |f|
          lines.each do |line|
            f.puts line
          end
        end
      end
    end


    def print_post_installation_instructions
      @logger.info <<-EOS

Yay! Your theme is installed!

What now?
1) Ensure your new application layout file contains everything that you wanted
   from the old one.
2) Restart your development server if it is currently running.
3) Let us know how it went: @railsthemes or team@railsthemes.com.
      EOS
    end

    def print_usage_and_abort s
      print_usage
      Safe.log_and_abort s
    end
  end
end
