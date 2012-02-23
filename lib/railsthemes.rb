require 'railsthemes/version'
require 'railsthemes/safe'
require 'date'

module Railsthemes
  def self.execute args
    if args[0] == 'install' && args.length > 1
      install *args[1..-1]
    else
      Safe.print_usage
    end
  end

  def self.install *args
    if args[0] == '--file'
      if args[1]
        install_from_file_system args[1]
      else
        Safe.print_usage_and_abort "The parameter --file means we need another parameter after it to specify what file to load from."
      end
    elsif args[0] == '--help'
      Safe.print_usage
    else
      if args[0]
        download_from_hash args[0]
      else
        Safe.print_usage_and_abort "railsthemes expects the hash that you got from the website as a parameter in order to download the theme you bought."
      end
    end
  end

  def self.install_from_file_system filepath
    if Safe.directory?(filepath)
      files = files_under(filepath)
      puts 'Copying assets...'
      files_under(filepath).each do |file|
        copy_with_replacement filepath, file
      end
      puts 'Done copying assets.'
      post_copying_changes
      Safe.print_post_installation_instructions
    elsif archive?(filepath)
      install_from_archive filepath
    else
      Safe.print_usage_and_abort 'Need to specify either a directory or an archive file when --file is used.'
    end
  end

  def self.post_copying_changes
    Safe.remove_file File.join('public', 'index.html')
    puts 'Analyzing existing project structure...'
    if `rake routes`.length == 0 # brand new app
      `rails g controller Welcome index`
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
  end

  def self.install_from_archive filepath
    newdirpath = tmpdir
    Safe.make_directory newdirpath
    Safe.system_call untar_string(filepath, newdirpath)
    install_from_file_system newdirpath
    Safe.remove_directory newdirpath
  end

  def self.files_under filepath, accum = []
    files = Dir.chdir(filepath) { Dir['**/*'] }
    files.select{|f| !File.directory?(File.join(filepath, f))}
  end

  def self.download_from_hash hash
    puts "Downloading from hash #{hash}"
  end

  def self.copy_with_replacement filepath, entry
    if Safe.file_exists?(entry)
      # not sure if I should put in a cp -f here, might be better to toss error
      # so I'm using rename instead
      Safe.rename_file entry, entry + '.old'
    end
    Safe.copy_file File.join(filepath, entry), entry
  end

  def self.tmpdir
    File.join(Dir.tmpdir, DateTime.now.strftime("railsthemes-%Y%m%d-%H%M%s"))
  end

  def self.archive? filepath
    filepath =~ /\.tar$/ || filepath =~ /\.tar\.gz$/
  end

  def self.untar_string filepath, newdirpath
    gzipped = (filepath =~ /\.gz$/) ? 'z' : ''
    "tar -#{gzipped}xf #{filepath} -C #{newdirpath}"
  end
end
