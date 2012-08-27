module Railsthemes
  class AssetInstaller < Thor
    no_tasks do
      include Railsthemes::Logging
      include Thor::Actions

      def install_from_file_system original_source_filepath
        source_filepath = original_source_filepath.gsub(/\\/, '/')
        logger.warn 'Installing design assets...'
        logger.info "Source filepath: #{source_filepath}"

        if File.directory?(source_filepath)
          install_from_directory source_filepath
        elsif Utils.archive?(source_filepath + '.tar.gz')
          install_from_archive source_filepath + '.tar.gz'
        end
      end

      def install_from_directory source_filepath
        Dir["#{source_filepath}/design-assets/**/*"].each do |src|
          logger.debug "src: #{src}"
          dest = src.sub("#{source_filepath}/design-assets/", '')
          logger.debug "dest: #{dest}"
          if File.directory?(src)
            unless File.directory?(dest)
              logger.debug "mkdir -p #{dest}"
              FileUtils.mkdir_p(dest)
            end
          else
            unless src =~ /\/\./ # remove any pesky hidden files that crept into the archive
              logger.debug "cp #{src} #{dest}"
              FileUtils.cp(src, dest)
            end
          end
        end

        logger.warn 'Done installing design assets.'
      end

      def install_from_archive filepath
        Railsthemes::Utils.with_tempdir do |tempdir|
          Utils.unarchive filepath, tempdir
          install_from_file_system tempdir
        end
      end
    end
  end
end
