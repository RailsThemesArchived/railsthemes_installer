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
    def self.download params = {}
      url = params[:url]
      save_to = params[:save_to]
      return unless url && save_to
      logger.info "Downloading url: #{url}"
      logger.info "Saving to: #{save_to}"
      uri = URI(url)
      http = Net::HTTP.new uri.host, uri.port
      set_https http if uri.scheme == 'https'
      path = url.gsub(%r{https?://[^/]+}, '')
      response = http.get(path)
      if response.code.to_s == '200'
        File.open(save_to, 'wb') do |file|
          file.write(response.body)
        end
      else
        logger.debug "response.code: #{response.code}"
        logger.debug "response.body: #{response.body}"
        Safe.log_and_abort 'Had trouble downloading a file and cannot continue.'
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
      File.exists?(filepath) && filepath =~ /\.tar\.gz$/
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
      Safe.log_and_abort "Archive expected at #{archive}, but none exists." unless File.exist?(archive)
      logger.warn "Extracting..."
      logger.info "Attempting to extract #{archive}"
      io = Tar.ungzip(File.open(archive, 'rb'))
      Tar.untar(io, extract_to)
      logger.warn "Finished extracting."
    end

    def self.get_primary_configuration gemfile_contents = read_file('Gemfile.lock')
      gem_names = gemspecs(gemfile_contents).map(&:name)
      [(gem_names.include?('haml') ? 'haml' : 'erb'),
       (gem_names.include?('sass') ? 'scss' : 'css')]
    end

    # needs tests
    def self.conditionally_insert_routes routes_hash
      if File.exists?(File.join('config', 'routes.rb'))
        lines = Utils.read_file('config/routes.rb').split("\n")
        last = lines.pop
        routes_hash.each do |first, second|
          if lines.grep(/#{second}/).empty?
            lines << "  match '#{first}' => '#{second}'"
          end
        end
        lines << last
        File.open(File.join('config', 'routes.rb'), 'w') do |f|
          lines.each do |line|
            f.puts line
          end
        end
      end
    end

    # needs tests
    def self.conditionally_install_gems *gem_names
      if File.exists?('Gemfile')
        lines = Utils.read_file('Gemfile').split("\n")
        gem_names.each do |gem_name|
          if lines.grep(/#{gem_name}/).empty?
            lines << "gem '#{gem_name}'"
          end
        end
        File.open('Gemfile', 'w') do |f|
          lines.each do |line|
            f.puts line
          end
        end

        # actually install the gems
        Safe.system_call 'bundle'
      end
    end
  end
end
