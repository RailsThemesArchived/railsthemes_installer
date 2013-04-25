module Railsthemes
  class EmailInstaller
    include Railsthemes::Logging

    def install_from_file_system source_filepath
      theme_name = Utils.read_file(File.join(source_filepath, 'theme_name')).chomp
      if Dir["app/mailers/railsthemes_#{theme_name}/*"].count > 0

        logger.warn 'Installing email...'
        logger.info "Source filepath: #{source_filepath}"

        unless File.directory?(source_filepath)
          Safe.log_and_abort 'Expected a directory to install email theme from, but found none.'
        end

        add_to_asset_precompilation_list theme_name
        install_mail_gems_if_necessary

        logger.warn 'Done installing email.'
        true
      else
        false
      end
    end

    def add_to_asset_precompilation_list theme_name
      filenames = Dir["app/assets/stylesheets/railsthemes_#{theme_name}/*_email.css*"]
      filenames.map! do |filename|
        "railsthemes_#{theme_name}/#{File.basename(filename.gsub(/\.erb$/, ''))}"
      end

      config_lines = Utils.lines('config/environments/production.rb')
      email_regex = /^\s*config.assets.precompile\s*\+=\s*%w\(\s*railsthemes_#{theme_name}\/\w*email\.css \)$/
      count = config_lines.grep(email_regex).count
      if count == 0 # precompile line we want not found, add it
        added = false # only want to add the new line once
        Utils.safe_write('config/environments/production.rb') do |f|
          config_lines.each do |line|
            f.puts line
            if !added && (line =~ /Precompile additional assets/ || line =~ /config\.assets\.precompile/)
              string = '  config.assets.precompile += %w( '
              string += filenames.join(' ')
              string += ' )'
              f.puts string
              added = true
            end
          end
        end
      else
        Utils.safe_write('config/environments/production.rb') do |f|
          config_lines.each do |line|
            if line =~ email_regex
              string = '  config.assets.precompile += %w( '
              string += filenames.join(' ')
              string += ' )'
              f.puts string
            else
              f.puts line
            end
          end
        end
      end
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
