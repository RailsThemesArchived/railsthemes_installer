require 'date'
require 'fileutils'
require 'logger'
require 'tmpdir'

module Railsthemes
  class Installer
    def initialize logger = nil
      @logger = logger
      @logger ||= Logger.new(STDOUT)
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "#{msg}\n"
      end
    end

    def execute args = []
      if args[0] == 'install' && args.length > 1
        install *args[1..-1]
      else
        print_usage
      end
    end

    def install *args
      ensure_in_rails_root
      if args[0] == '--file'
        if args[1]
          install_from_file_system args[1]
        else
          print_usage_and_abort "The parameter --file means we need another parameter after it to specify what file to load from."
        end
      elsif args[0] == '--help'
        print_usage
      else
        if args[0]
          download_from_hash args[0]
        else
          print_usage_and_abort "railsthemes expects the hash that you got from the website as a parameter in order to download the theme you bought."
        end
      end
    end

    def ensure_in_rails_root
      unless File.directory?('app') && File.directory?('public')
        Safe.log_and_abort 'Must be in the Rails root directory to use this gem.'
      end
    end

    def install_from_file_system filepath
      if File.directory?(filepath)
        files = files_under(filepath)
        @logger.info 'Copying assets...'
        files.each do |file|
          copy_with_replacement filepath, file
        end
        @logger.info 'Done copying assets.'
        post_copying_changes
        print_post_installation_instructions
      elsif archive?(filepath)
        if File.exists?(filepath)
          install_from_archive filepath
          # no need for post_installation, because we haven't
        else
          Safe.log_and_abort 'Cannot find the file you specified.'
        end
      else
        print_usage_and_abort 'Need to specify either a directory or an archive file when --file is used.'
      end
    end

    # this happens after a successful copy so that we set up the environment correctly
    def post_copying_changes
      Utils.remove_file File.join('public', 'index.html')
      @logger.info 'Analyzing existing project structure...'
      create_welcome_controller unless routes_defined?
    end

    def create_welcome_controller
      Safe.system_call('rails g controller Welcome index')
      lines = []
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

    def routes_defined?
      Safe.system_call('rake routes').length > 0
    end

    def install_from_archive filepath
      tempdir = generate_tmpdir
      Dir.mkdir tempdir
      Safe.system_call untar_string(filepath, tempdir)
      install_from_file_system tempdir
      #FileUtils.rm_rf tempdir
    end

    def files_under filepath, accum = []
      files = Dir.chdir(filepath) { Dir['**/*'] }
      files.select{|f| !File.directory?(File.join(filepath, f))}
    end

    def download_from_hash hash
      @logger.info "Downloading from hash #{hash}"
    end

    def copy_with_replacement filepath, entry
      if File.exists?(entry)
        # not sure if I should put in a cp -f here, might be better to toss error
        # so I'm using rename instead
        File.rename entry, "#{entry}.old"
      end
      Utils.copy_with_path File.join(filepath, entry), entry
    end

    def generate_tmpdir
      File.join(Dir.tmpdir, DateTime.now.strftime("railsthemes-%Y%m%d-%H%M%s"))
    end

    def archive? filepath
      filepath =~ /\.tar$/ || filepath =~ /\.tar\.gz$/
    end

    def untar_string filepath, newdirpath
      gzipped = (filepath =~ /\.gz$/) ? 'z' : ''
      "tar -#{gzipped}xf #{filepath} --strip 1"
    end

    def print_usage
      @logger.info <<-EOS
Usage:
------
railsthemes install HASH
  install a theme from the railsthemes website

railsthemes install --help
  this message

railsthemes install --file filepath
  install from the local filesystem
      EOS
    end

    def print_post_installation_instructions
      @logger.info <<-EOS
Your theme is installed!

Make sure that you restart your server if it's currently running.
      EOS
    end

    def print_usage_and_abort s
      print_usage
      Safe.log_and_abort s
    end
  end
end
