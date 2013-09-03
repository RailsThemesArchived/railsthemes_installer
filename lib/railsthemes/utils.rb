module Railsthemes
  class Utils
    extend Railsthemes::Logging

    def self.remove_file filepath
      File.delete filepath if File.exists?(filepath)
    end

    def self.safe_write filepath, &block
      create_dir_for(filepath)
      File.open(filepath, 'w') do |f|
        yield f
      end
    end

    def self.safe_read_and_write filepath, &block
      create_dir_for(filepath)
      lines = read_file(filepath).split("\n")
      File.open(filepath, 'w') do |f|
        yield lines, f
      end
    end

    def self.create_dir_for filepath
      FileUtils.mkdir_p(File.dirname(filepath))
    end

    def self.copy_ensuring_directory_exists src, dest
      create_dir_for(dest)
      logger.debug "Copying #{src} to #{dest}"
      FileUtils.cp src, dest
    end

    def self.read_file filepath
      File.exists?(filepath) ? File.read(filepath) : ''
    end

    def self.lines filepath
      read_file(filepath).split("\n")
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
      set_https(http) if uri.scheme == 'https'
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

    def self.insert_into_routes_file! to_insert
      lines = lines('config/routes.rb')
      last = lines.pop
      lines += to_insert
      lines << last
      FileUtils.mkdir_p('config')
      File.open(File.join('config', 'routes.rb'), 'w') do |f|
        lines.each do |line|
          f.puts line
        end
      end
    end

    def self.add_gem_to_gemfile gem_name, attributes = {}
      File.open('Gemfile', 'a') do |f|
        line = "gem '#{gem_name}'"
        line += ", '#{attributes[:version]}'" if attributes[:version]
        line += ", :group => '#{attributes[:group]}'" if attributes[:group]
        line += " # RailsThemes"
        f.puts line
      end
    end

    def self.set_layout_in_application_controller theme_name
      ac_lines = Utils.lines('app/controllers/application_controller.rb')
      count = ac_lines.grep(/^\s*layout 'railsthemes/).count
      if count == 0 # layout line not found, add it
        Utils.safe_write('app/controllers/application_controller.rb') do |f|
          ac_lines.each do |line|
            f.puts line
            f.puts "  layout 'railsthemes_#{theme_name}'" if line =~ /^class ApplicationController/
          end
        end
      elsif count == 1 # layout line found, change it if necessary
        Utils.safe_write('app/controllers/application_controller.rb') do |f|
          ac_lines.each do |line|
            if line =~ /^\s*layout 'railsthemes_/
              f.puts "  layout 'railsthemes_#{theme_name}'"
            else
              f.puts line
            end
          end
        end
      else
        # multiple layout lines, not sure what to do here
      end
    end

  end
end
