module Railsthemes
  class Installer
    include Railsthemes::Logging

    def initialize options = {}
      @installed_email = false

      @doc_popup = !options[:no_doc_popup]
      server = 'http://staging.railsthemes.com' if options[:staging]
      server = options[:server] if options[:server]
      server ||= 'https://railsthemes.com'
      server = nil if options[:file]
      @server = server

      Railsthemes::Logging.verbose if options[:verbose]
      Railsthemes::Logging.debug if options[:debugging]
    end

    attr_accessor :doc_popup, :server

    def server= server
      @server = server
      Logging.logger.warn "Using server: #{@server}"
    end

    # can probably just make static
    def theme_installer
      @theme_installer ||= ThemeInstaller.new
    end

    def email_installer
      @email_installer ||= EmailInstaller.new
    end

    def popup_documentation
      latest_installed_dir = Dir.glob("doc/railsthemes_*").max_by {|f| File.mtime(f)}
      if latest_installed_dir
        Dir[File.join(latest_installed_dir, '*.html')].each do |document|
          logger.debug("document: #{document}")
          Launchy.open(document) if document
        end
      end
    end

    def install_from_file_system filepath
      Ensurer.ensure_clean_install_possible :server => false

      # install main theme
      filepath = filepath.gsub(/\\/, '/')
      filepath += '.tar.gz' if Utils.archive?(filepath + '.tar.gz')
      if Utils.archive?(filepath)
        install_from_archive filepath
      elsif File.directory?(filepath)
        theme_installer.install_from_file_system filepath
        @installed_email = email_installer.install_from_file_system filepath

        logger.warn 'Bundling to install new gems...'
        Safe.system_call 'bundle'
        logger.warn 'Done bundling.'

        print_post_installation_instructions
        popup_documentation if @doc_popup
      else
        Safe.log_and_abort "Could not find the file you need: #{filepath}"
      end
    end

    def install_from_archive filepath
      Railsthemes::Utils.with_tempdir do |tempdir|
        Utils.unarchive filepath, tempdir
        install_from_file_system tempdir
      end
    end

    def install_from_code code
      Ensurer.ensure_clean_install_possible :server => @server

      logger.warn "Figuring out what to download..."
      send_gemfile code

      download_url = get_download_url code

      if download_url
        logger.debug "download_url: #{download_url}"
        Utils.with_tempdir do |tempdir|
          download_from_url download_url, tempdir
          install_from_file_system File.join(tempdir, 'rt-archive')
        end
      else
        Safe.log_and_abort "We didn't recognize the code you gave to download the theme (#{code}).\n" +
                           "It should look something like your@email.com:ABCDEF."
      end
    end

    def get_download_url code
      config = Utils.get_primary_configuration
      server_request_url = "#{@server}/download?code=#{code}&config=#{config * ','}&v=2"
      response = nil

      begin
        response = Utils.get_url server_request_url
      rescue SocketError => e
        Safe.log_and_abort 'We could not reach the RailsThemes server to download the theme. Please check your internet connection and try again.'
      rescue Exception => e
        logger.debug e.message
        logger.debug e.backtrace
      end

      if response
        if response.code.to_s == '200'
          response.body
        else
          logger.debug "download_url response code: #{response[:code]}"
          nil
        end
      end
    end

    def download_from_url url, download_to
      if url
        logger.warn "Downloading theme..."
        config = Utils.get_primary_configuration
        archive = File.join(download_to, "rt-archive.tar.gz")
        Utils.download :url => url, :save_to => archive
        logger.warn "Done downloading theme."
      end
    end

    def send_gemfile code
      return nil unless File.exists?('Gemfile.lock')
      begin
        RestClient.post("#{@server}/gemfiles/parse",
          :code => code, :gemfile_lock => File.new('Gemfile.lock', 'rb'))
      rescue SocketError => e
        Safe.log_and_abort 'We could not reach the RailsThemes server to start your download. Please check your internet connection and try again.'
      rescue Exception => e
        logger.info e.message
        logger.info e.backtrace
      end
    end

    def print_post_installation_instructions
      logger.warn <<-EOS

Yay! Your theme is installed!


Documentation and help
======================

Theme documentation is located in the doc folder.

There are some help articles for your perusal at http://support.railsthemes.com.


What now?
EOS
      with_number "Start or restart your development server."
      with_number("Check out the local theme samples at:  http://localhost:3000/railsthemes")
      with_number("Ensure your new application layout file contains everything that you wanted",
                  "from the old one.")
      with_number("For instructions on how to send RailsThemes-styled emails in your app,",
                  "check out the documentation in the docs folder.") if @installed_email
      with_number "Let us know how it went: @railsthemes or support@railsthemes.com."
    end

    def with_number *lines
      @number ||= 0
      logger.warn "#{@number += 1}) #{lines[0]}"
      lines[1..-1].each do |line|
        logger.warn "   #{line}"
      end
    end
  end
end
