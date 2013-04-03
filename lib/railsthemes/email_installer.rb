module Railsthemes
  class EmailInstaller
    include Railsthemes::Logging

    def install
      logger.warn 'Installing email...'

      install_mail_gems_if_necessary

      logger.warn 'Done installing email.'
    end

    def install_mail_gems_if_necessary
      gem_names = Utils.gemspecs.map(&:name)
      logger.debug "gem_names: #{gem_names}"
      unless gem_names.include?('premailer-rails')
        if (gem_names & ['hpricot', 'nokogiri']).empty?
          Utils.add_gem_to_gemfile 'hpricot'
        end
        logger.warn 'Installing assistant mail gems...'
        Utils.add_gem_to_gemfile 'premailer-rails'
        logger.warn 'Done installing assistant mail gems.'
      end
    end
  end
end
