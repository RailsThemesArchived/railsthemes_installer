module Railsthemes
  class Installer < Thor
    no_tasks do
      include Railsthemes::Logging
      include Thor::Actions

      def initialize
        @doc_popup = true
        @installed_email = false
      end

      def doc_popup= doc_popup
        @doc_popup = doc_popup
      end

      # can probably just make static
      def theme_installer
        @theme_installer ||= ThemeInstaller.new
      end

      # can probably just make static
      def email_installer
        @email_installer ||= EmailInstaller.new
      end

      def popup_documentation
        style_guides = Dir['doc/*Usage_And_Style_Guide.html']
        # need better tests of popping up multiple docs
        style_guides.each do |style_guide|
          logger.debug("style_guide: #{style_guide}")
          Launchy.open(style_guide) if style_guide
        end
      end

      # primary method
      def install_from_file_system original_source_filepath
        Ensurer.ensure_clean_install_possible

        # install main theme
        config = Utils.get_primary_configuration
        filepath = File.join(original_source_filepath, config.join('-'))
        if File.directory?(filepath) || Utils.archive?(filepath + '.tar.gz')
          theme_installer.install_from_file_system filepath
        else
          Safe.log_and_abort "Could not find the file you need: #{filepath}"
        end

        # install email theme if present
        filepath = File.join(original_source_filepath, 'email')
        if File.directory?(filepath) || Utils.archive?(filepath + '.tar.gz')
          email_installer.install_from_file_system filepath
          @installed_email = true
        else
          # no email to install... moving along
        end

        print_post_installation_instructions
        popup_documentation if @doc_popup
      end

      # primary method
      def install_from_code code
        Ensurer.ensure_clean_install_possible

        logger.warn "Figuring out what to download..."
        send_gemfile code

        dl_hash = get_download_hash code

        if dl_hash
          logger.debug "dl_hash: #{dl_hash.to_s}"
          Utils.with_tempdir do |tempdir|
            download_from_hash dl_hash, tempdir
            install_from_file_system tempdir
          end
        else
          Safe.log_and_abort("We didn't recognize the code you gave to download the theme (#{code}). It should look something like your@email.com:ABCDEF.")
        end
      end


      def get_download_hash code
        config = Utils.get_primary_configuration
        server_request_url = "#{Railsthemes.server}/download?code=#{code}&config=#{config * ','}&v=2"
        response = nil
        begin
          response = Utils.get_url server_request_url
        rescue SocketError => e
          Safe.log_and_abort 'We could not reach the RailsThemes server to download the theme. Please check your internet connection and try again.'
        rescue Exception => e
          logger.debug e.message
          logger.debug e.backtrace
        end

        if response && response.code.to_s == '200'
          JSON.parse(response.body)
        else
          nil
        end
      end

      def download_from_hash dl_hash, download_to
        url = dl_hash['theme']
        if url
          logger.warn "Downloading main theme..."
          config = Utils.get_primary_configuration
          archive = File.join(download_to, "#{config.join('-')}.tar.gz")
          Utils.download :url => url, :save_to => archive
          logger.warn "Done downloading main theme."
        end

        url = dl_hash['email']
        if url
          logger.warn "Downloading email theme..."
          archive = File.join(download_to, 'email.tar.gz')
          Utils.download :url => url, :save_to => archive
          logger.warn "Done downloading email theme."
        end
      end

      def send_gemfile code
        return nil unless File.exists?('Gemfile.lock')
        begin
          RestClient.post("#{Railsthemes.server}/gemfiles/parse",
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

=============================

Documentation and help

Theme documentation is located in the doc folder.

There are some help articles for your perusal at http://support.railsthemes.com.


What now?
EOS
        with_number("Make sure that you have the jquery-rails gem installed. All of the current",
                    "themes require this in your Gemfile so we can use jQuery UI.")
        with_number "Start or restart your development server."
        with_number("Check out the local theme samples at:",
                    "http://localhost:3000/railsthemes/landing",
                    "http://localhost:3000/railsthemes/inner",
                    "http://localhost:3000/railsthemes/jquery_ui")
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
end
