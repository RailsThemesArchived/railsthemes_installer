module Railsthemes
  class ThemeInstaller < Thor
    no_tasks do
      include Railsthemes::Logging
      include Thor::Actions

      def install_from_archive filepath
        Railsthemes::Utils.with_tempdir do |tempdir|
          Utils.unarchive filepath, tempdir
          install_from_file_system tempdir
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
            Safe.log_and_abort "Cannot find the file you specified: #{source_filepath}"
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

        Utils.conditionally_insert_routes({
          'railsthemes/landing' => 'railsthemes#landing',
          'railsthemes/inner' => 'railsthemes#inner',
          'railsthemes/jquery_ui' => 'railsthemes#jquery_ui'
        })

        logger.warn 'Done creating RailsThemes demo pages.'
      end

    end
  end
end
