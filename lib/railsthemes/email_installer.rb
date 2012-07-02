module Railsthemes
  class EmailInstaller < Thor
    no_tasks do
      include Railsthemes::Logging
      include Thor::Actions

      def install_from_file_system original_source_filepath
        source_filepath = original_source_filepath.gsub(/\\/, '/')
        logger.warn 'Installing email theme...'
        logger.info "Source filepath: #{source_filepath}"

        if File.directory?(source_filepath)
          install_from_directory source_filepath
        elsif Utils.archive?(source_filepath + '.tar.gz')
          install_from_archive source_filepath + '.tar.gz'
        end
      end

      def install_from_directory source_filepath
        Dir["#{source_filepath}/email/**/*"].each do |src|
          logger.debug "src: #{src}"
          dest = src.sub("#{source_filepath}/email/", '')
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

        inject_into_file File.join('app', 'controllers', 'railsthemes_controller.rb'), :after => 'class RailsthemesController < ApplicationController' do
<<-EOS

def email
end

def send_email
  RailsthemesMailer.test_email(:to => params[:email]).deliver
  render :sent_email
end
EOS
        end

        Utils.conditionally_insert_routes({
          'railsthemes/email' => 'railsthemes#email',
          'railsthemes/send_email' => 'railsthemes#send_email'
        })

        Utils.conditionally_install_gems 'roadie'

        logger.warn 'Done installing email theme.'
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
