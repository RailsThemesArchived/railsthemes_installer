module Railsthemes
  class ThemeInstaller
    include Railsthemes::Logging

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

      post_copying_changes
    end

    def copy_theme_portions source_filepath, file_map
      file_map.each do |chunk, prefix|
        Dir["#{source_filepath}/#{chunk}/**/*"].each do |src|
          dest = src.sub("#{source_filepath}", prefix)
          dest.gsub!(/^\//, '') # remove / at beginning of file prefix
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
      # it in the ERB case, so safe to delete before copying files
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

    def post_copying_changes
      remove_unwanted_public_files
      create_railsthemes_demo_routes
      add_needed_gems
    end

    def remove_unwanted_public_files
      Utils.remove_file 'public/index.html'
      Utils.remove_file 'public/404.html'
      Utils.remove_file 'public/422.html'
      Utils.remove_file 'public/500.html'
    end

    def create_railsthemes_demo_routes
      logger.warn 'Creating RailsThemes demo pages...'

      Utils.conditionally_insert_routes({
        'railsthemes/landing' => 'railsthemes#landing',
        'railsthemes/inner' => 'railsthemes#inner',
        'railsthemes/jquery_ui' => 'railsthemes#jquery_ui'
      })

      logger.warn 'Done creating RailsThemes demo pages.'
    end

    def add_needed_gems
    end
  end
end
