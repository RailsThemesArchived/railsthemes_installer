require 'railsthemes/version'
require 'railsthemes/safe'

module Railsthemes
  def self.execute args
    if args[0] == 'install'
      Railsthemes.install args[1..-1]
    else
      Railsthemes.print_usage
    end
  end

  def self.install *args
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

  def self.install_from_file_system filepath
    puts "install_from_file_system #{filepath}"
    if Safe.directory?(filepath)
      Safe.directory_entries_for(filepath).each do |entry|
        next if entry == '.' || entry == '..'
        copy_with_replacement filepath, entry
      end
    elsif archive?(filepath)
      newdirpath = tmpdir
      Safe.make_directory newdirpath
      Safe.system_call untar(filepath, newdirpath)
      install_from_file_system newdirpath
      Safe.remove_directory newdirpath
    else
      Safe.print_usage_and_abort 'Need to specify either a directory or an archive file when --file is used.'
    end
  end

  def self.download_from_hash hash
  end

  def self.copy_with_replacement filepath, entry
    if Safe.file_exists?(entry)
      # not sure if I should put in a cp -f here, might be better to toss error
      # so I'm using rename instead
      Safe.rename_file entry, File.join(entry + '.old')
    end
    Safe.copy_file_with_force File.join(filepath, entry), entry
  end

  def self.tmpdir
    File.join(Dir.tmpdir, DateTime.new.strftime("railsthemes-%Y%m%d-%H%M%s"))
  end

  def self.archive? filepath
    filepath =~ /\.tar$/ || filepath =~ /\.tar\.gz$/
  end

  def self.untar filepath, newdirpath
    gzipped = (filepath =~ /\.gz$/) ? 'z' : ''
    "tar -#{gzipped}xf #{filepath} -C #{newdirpath}"
  end

end
