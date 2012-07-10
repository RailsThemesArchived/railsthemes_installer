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

        inject_into_file File.join('app', 'controllers', 'railsthemes_controller.rb'), :after => 'class RailsthemesController < ApplicationController', :verbose => false do
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

        install_mail_gems_if_necessary

        create_file File.join('config', 'initializers', 'premailer.rb'), :verbose => false do
          "PremailerRails.config.merge(:input_encoding => 'UTF-8', :generate_text_part => true)"
        end

        logger.warn 'Done installing email theme.'
      end

      def install_mail_gems_if_necessary
        gem_names = Utils.gemspecs.map(&:name)
        unless gem_names.include?('premailer-rails3')
          if (gem_names & ['hpricot', 'nokogiri']).empty?
            Utils.add_gem_to_gemfile 'hpricot'
          end
          Utils.add_gem_to_gemfile 'premailer-rails3'
          Safe.system_call 'bundle'
        end
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
