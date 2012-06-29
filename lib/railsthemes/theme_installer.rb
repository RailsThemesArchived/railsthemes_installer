require 'thor'

module Railsthemes
  class ThemeInstaller < Thor
    no_tasks do
      include Railsthemes::Logging
      include Thor::Actions

      def install_from_server code
        logger.warn "Downloading theme from server..."
        Utils.with_tempdir do |tempdir|
          archive = File.join(tempdir, 'archive.tar.gz')
          if File.exists?('Gemfile.lock')
            send_gemfile code # first time hitting the server
          end
          config = Utils.get_primary_configuration(Utils.read_file('Gemfile.lock'))
          dl_url = get_download_url "#{Railsthemes.server}/download?code=#{code}&config=#{config * ','}"
          if dl_url
            Utils.download_file_to dl_url, archive
            logger.warn "Finished downloading."
            install_from_archive archive
          else
            Safe.log_and_abort("We didn't recognize the code you gave to download the theme (#{code}). It should look something like your@email.com:ABCDEF.")
          end
        end
      end

      def install_from_archive filepath
        Railsthemes::Utils.with_tempdir do |tempdir|
          Utils.unarchive filepath, tempdir
          install_from_file_system tempdir
        end
      end

      def send_gemfile code
        begin
          response = RestClient.post("#{Railsthemes.server}/gemfiles/parse",
            :code => code, :gemfile_lock => File.new('Gemfile.lock', 'rb'))
        rescue SocketError => e
          Safe.log_and_abort 'We could not reach the RailsThemes server to start your download. Please check your internet connection and try again.'
        rescue Exception => e
          logger.info e.message
          logger.info e.backtrace
        end
      end

      def get_download_url server_request_url
        response = nil
        begin
          response = Utils.get_url server_request_url
        rescue SocketError => e
          Safe.log_and_abort 'We could not reach the RailsThemes server to download the theme. Please check your internet connection and try again.'
        rescue Exception => e
          logger.info e.message
          logger.info e.backtrace
        end

        if response && response.code.to_s == '200'
          response.body
        else
          nil
        end
      end

      def install_from_file_system original_source_filepath
        source_filepath = original_source_filepath.gsub(/\\/, '/')
        if File.directory?(source_filepath)
          logger.warn 'Installing...'

          # this file causes issues when HAML is also present, and we overwrite
          # it in the ERB case, so safe to delete here
          logger.debug 'removing file app/views/layouts/application.html.erb'
          Utils.remove_file('app/views/layouts/application.html.erb')

          logger.debug "source_filepath: #{source_filepath}"
          Dir["#{source_filepath}/base/**/*"].each do |src|
            logger.debug "src: #{src}"
            dest = src.sub("#{source_filepath}/base/", '')
            logger.debug "dest: #{dest}"
            if File.directory?(src)
              unless File.directory?(dest)
                logger.debug "mkdir -p #{dest}"
                FileUtils.mkdir_p(dest)
              end
            else
              unless (dest =~ /railsthemes_.*_overrides\.*/ && File.exists?(dest)) ||
                  src =~ /\/\./ # remove any pesky hidden files that crept into the archive
                logger.debug "cp #{src} #{dest}"
                FileUtils.cp(src, dest)
              end
            end
          end

          gem_names = Utils.gemspecs(Utils.read_file('Gemfile.lock')).map(&:name) - ['haml', 'sass']
          install_gems_from(source_filepath, gem_names)

          logger.warn 'Done installing.'

          post_copying_changes
        elsif Railsthemes::Utils.archive?(source_filepath)
          if File.exists?(source_filepath)
            install_from_archive source_filepath
            # no need for post_installation, because we will do this in install_from_archive
          else
            Safe.log_and_abort 'Cannot find the file you specified.'
          end
        else
          Safe.log_and_abort 'Need to specify either a directory or an archive file when --file is used.'
        end
      end

      def self.install_from_file_system original_source_filepath
        source_filepath = original_source_filepath.gsub(/\\/, '/')
        if File.directory?(source_filepath)
          logger.warn 'Installing...'

          # this file causes issues when HAML is also present, and we overwrite
          # it in the ERB case, so safe to delete here
          logger.debug 'removing file app/views/layouts/application.html.erb'
          Utils.remove_file('app/views/layouts/application.html.erb')

          logger.debug "source_filepath: #{source_filepath}"
          Dir["#{source_filepath}/base/**/*"].each do |src|
            logger.debug "src: #{src}"
            dest = src.sub("#{source_filepath}/base/", '')
            logger.debug "dest: #{dest}"
            if File.directory?(src)
              unless File.directory?(dest)
                logger.debug "mkdir -p #{dest}"
                FileUtils.mkdir_p(dest)
              end
            else
              unless (dest =~ /railsthemes_.*_overrides\.*/ && File.exists?(dest)) ||
                  src =~ /\/\./ # remove any pesky hidden files that crept into the archive
                logger.debug "cp #{src} #{dest}"
                FileUtils.cp(src, dest)
              end
            end
          end

          gem_names = Utils.gemspecs(Utils.read_file('Gemfile.lock')).map(&:name) - ['haml', 'sass']
          install_gems_from(source_filepath, gem_names)

          logger.warn 'Done installing.'

          post_copying_changes
        elsif Railsthemes::Utils.archive?(source_filepath)
          if File.exists?(source_filepath)
            install_from_archive source_filepath
            # no need for post_installation, because we will do this in install_from_archive
          else
            Safe.log_and_abort 'Cannot find the file you specified.'
          end
        else
          Safe.log_and_abort 'Need to specify either a directory or an archive file when --file is used.'
        end
      end

      def install_gems_from source_filepath, gem_names
        return unless File.directory?("#{source_filepath}/gems")
        logger.debug "gem_names: #{gem_names * ' '}"
        gems_that_we_can_install = Dir.entries("#{source_filepath}/gems").reject{|x| x == '.' || x == '..'}
        logger.debug "gems_that_we_can_install: #{gems_that_we_can_install * ' '}"
        (gem_names & gems_that_we_can_install).each do |gem_name|
          gem_src = File.join(source_filepath, 'gems', gem_name)
          logger.debug("copying gems from #{gem_src}")
          Dir["#{gem_src}/**/*"].each do |src|
            logger.debug "src: #{src}"
            dest = src.sub("#{source_filepath}/gems/#{gem_name}/", '')
            logger.debug "dest: #{dest}"
            if File.directory?(src)
              logger.debug "mkdir -p #{dest}"
              FileUtils.mkdir_p(dest)
            else
              unless src =~ /\/\./ # remove any pesky hidden files that crept into the archive
                logger.debug "cp #{src} #{dest}"
                FileUtils.cp(src, dest)
              end
            end
          end
        end
      end

      # this happens after a successful copy so that we set up the environment correctly
      # for people to view the theme correctly
      def post_copying_changes
        logger.info "Removing public/index.html"
        Utils.remove_file File.join('public', 'index.html')
        create_railsthemes_demo_pages
      end

      def create_railsthemes_demo_pages
        logger.warn 'Creating RailsThemes demo pages...'

        logger.debug "mkdir -p app/controllers"
        FileUtils.mkdir_p(File.join('app', 'controllers'))
        logger.debug "writing to app/controllers/railsthemes_controller.rb"
        File.open(File.join('app', 'controllers', 'railsthemes_controller.rb'), 'w') do |f|
          f.write <<-EOS
class RailsthemesController < ApplicationController
  # normally every view will use your application layout
  def inner
    render :layout => 'application'
  end

  # this is a special layout for landing and home pages
  def landing
    render :layout => 'landing'
  end
end
          EOS
        end

        lines = []
        if File.exists?(File.join('config', 'routes.rb'))
          lines = Utils.read_file('config/routes.rb').split("\n")
          last = lines.pop
          if lines.grep(/railsthemes#landing/).empty?
            lines << "  match 'railsthemes/landing' => 'railsthemes#landing'"
          end
          if lines.grep(/railsthemes#inner/).empty?
            lines << "  match 'railsthemes/inner' => 'railsthemes#inner'"
          end
          if lines.grep(/railsthemes#jquery_ui/).empty?
            lines << "  match 'railsthemes/jquery_ui' => 'railsthemes#jquery_ui'"
          end
          lines << last
          File.open(File.join('config', 'routes.rb'), 'w') do |f|
            lines.each do |line|
              f.puts line
            end
          end
        end

        logger.warn 'Done creating RailsThemes demo pages.'
      end

    end
  end
end
