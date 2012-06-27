require 'fileutils'
require 'open-uri'
require 'railsthemes/os'

module Railsthemes
  class Utils
    extend Railsthemes::Logging

    # remove file only if it exists
    def self.remove_file filepath
      if File.exists?(filepath)
        File.delete filepath
      end
    end

    # copy a file, ensuring that the directory is present
    def self.copy_ensuring_directory_exists src, dest
      FileUtils.mkdir_p(File.dirname(dest)) # create directory if necessary
      FileUtils.cp src, dest
    end

    def self.read_file filepath
      File.exists?(filepath) ? File.read(filepath) : ''
    end

    # would be nice to put download status in the output (speed, progress, etc.)
    # needs tests
    def self.download_file_to url, save_to
      uri = URI(url)
      http = Net::HTTP.new uri.host, uri.port
      set_https http if uri.scheme == 'https'
      path = url.gsub(%r{https?://[^/]+}, '')
      response = http.get(path)
      File.open(save_to, 'wb') do |file|
        file.write(response.body)
      end
    end

    # needs tests I think
    def self.get_url url
      uri = URI.parse url
      http = Net::HTTP.new uri.host, uri.port
      set_https http if uri.scheme == 'https'
      path = url.gsub(%r{https?://[^/]+}, '')
      http.request_get(path)
    end

    # needs tests
    def self.set_https http
      cacert_file = File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', 'cacert.pem')
      http.ca_file = cacert_file
      http.ca_path = cacert_file
      ENV['SSL_CERT_FILE'] = cacert_file

      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end

    def self.archive? filepath
      filepath =~ /\.tar\.gz$/
    end

    # needs tests
    def self.with_tempdir &block
      tempdir = generate_tempdir_name
      FileUtils.mkdir_p tempdir
      yield tempdir
      FileUtils.rm_rf tempdir
    end

    # needs tests
    def self.generate_tempdir_name
      tempdir = File.join(Dir.tmpdir, DateTime.now.strftime("railsthemes-%Y%m%d-%H%M%S-#{rand(100000000)}"))
      logger.debug "tempdir: #{tempdir}"
      tempdir
    end

    # needs tests
    def self.gemspecs gemfile_contents = nil
      gemfile_contents ||= Utils.read_file('Gemfile.lock')
      return [] if gemfile_contents.strip == ''
      lockfile = Bundler::LockfileParser.new(gemfile_contents)
      lockfile.specs
    end

    def self.unarchive archive, extract_to
      logger.warn "Extracting..."
      io = Tar.ungzip(File.open(archive, 'rb'))
      Tar.untar(io, extract_to)
      logger.warn "Finished extracting."
    end
  end
end
