module Railsthemes
  class EmailInstaller
    include Railsthemes::Logging

    def install
      logger.warn 'Installing email...'

      install_mail_gems_if_necessary
      add_premailer_config_file

      logger.warn 'Done installing email.'
    end

    def install_mail_gems_if_necessary
      gem_names = Utils.gemspecs.map(&:name)
      logger.debug "gem_names: #{gem_names}"
      unless gem_names.include?('premailer-rails3')
        if (gem_names & ['hpricot', 'nokogiri']).empty?
          Utils.add_gem_to_gemfile 'hpricot'
        end
        logger.warn 'Installing assistant mail gems...'
        Utils.add_gem_to_gemfile 'premailer-rails3'
        logger.warn 'Done installing assistant mail gems.'
      end
    end

    def add_premailer_config_file
      Utils.safe_write('config/initializers/premailer.rb') do |f|
        f.puts "PremailerRails.config.merge(:input_encoding => 'UTF-8', :generate_text_part => true)"
      end
    end
  end
end
