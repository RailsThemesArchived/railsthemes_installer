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
        logger.warn 'Installing main theme...'
        logger.info "Source filepath: #{source_filepath}"

        if File.directory?(source_filepath)
          install_from_directory source_filepath
        elsif Utils.archive?(source_filepath + '.tar.gz')
          install_from_archive(source_filepath + '.tar.gz')
        else
          Safe.log_and_abort 'Expected either a directory or archive.'
        end
      end

      def copy_theme_portions source_filepath, file_map
        file_map.each do |chunk, prefix|
          Dir["#{source_filepath}/#{chunk}/**/*"].each do |src|
            dest = src.sub("#{source_filepath}", prefix)
            dest.gsub!(/^\//, '')
            if File.file?(src)
              unless (dest =~ /overrides/ && File.exists?(dest)) ||
                  src =~ /\/\./ # remove any pesky hidden files that crept into the archive
                FileUtils.mkdir_p(File.dirname(dest))
                FileUtils.cp(src, dest)
              end
            end
          end
        end
      end

      def install_from_directory source_filepath
        # this file causes issues when HAML is also present, and we overwrite
        # it in the ERB case, so safe to delete here
        logger.debug 'removing file app/views/layouts/application.html.erb'
        Utils.remove_file('app/views/layouts/application.html.erb')

        copy_theme_portions source_filepath, [
          ['controllers', 'app'],
          ['helpers', 'app'],
          ['layouts', 'app/views'],
          ['stylesheets', 'app/assets'],
          ['javascripts', 'app/assets'],
          ['doc', ''],
          ['images', 'app/assets'],
          ['mailers', 'app'],
        ]

        logger.warn 'Done installing.'
      end

      # this happens after a successful copy so that we set up the environment correctly
      # for people to view the theme correctly
      def post_copying_changes
        logger.info "Removing public/index.html"
        Utils.remove_file File.join('public', 'index.html')
        Utils.remove_file File.join('public', '404.html')
        Utils.remove_file File.join('public', '422.html')
        Utils.remove_file File.join('public', '500.html')
        create_railsthemes_demo_pages
      end

      def create_railsthemes_demo_pages
        logger.warn 'Creating RailsThemes demo pages...'

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
