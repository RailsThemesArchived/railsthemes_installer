module Railsthemes
  class EmailInstaller
    include Railsthemes::Logging

    def install
      logger.warn 'Installing email...'

      add_routes_if_necessary
      install_mail_gems_if_necessary

      create_file File.join('config', 'initializers', 'premailer.rb'), :verbose => false do
        "PremailerRails.config.merge(:input_encoding => 'UTF-8', :generate_text_part => true)"
      end

      logger.warn 'Done installing email.'
    end

    def add_routes_if_necessary
      routes_hash = {
        'railsthemes/email' => 'railsthemes#email',
        'railsthemes/send_email' => 'railsthemes#send_email'
      }

      if File.exists?(File.join('config', 'routes.rb'))
        lines = Utils.lines('config/routes.rb')
        to_insert = []
        routes_hash.each do |first, second|
          if lines.grep(/#{second}/).empty?
            to_insert << "  match '#{first}' => '#{second}'"
          end
        end
        insert_into_routes_file! to_insert
      end
    end

    def install_mail_gems_if_necessary
      gem_names = Utils.gemspecs.map(&:name)
      logger.debug "gem_names: #{gem_names}"
      unless gem_names.include?('premailer-rails3')
        if (gem_names & ['hpricot', 'nokogiri']).empty?
          Utils.add_gem_to_gemfile 'hpricot'
        end
        Utils.add_gem_to_gemfile 'premailer-rails3'
        logger.warn 'Installing assistant mail gems...'
        Safe.system_call 'bundle'
        logger.warn 'Done installing assistant mail gems.'
      end
    end
  end
end
