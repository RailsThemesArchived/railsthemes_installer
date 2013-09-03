module Railsthemes
  class ThemeInstaller
    include Railsthemes::Logging

    def install_from_file_system source_filepath
      logger.warn 'Installing main theme...'
      logger.info "Source filepath: #{source_filepath}"

      unless File.directory?(source_filepath)
        Safe.log_and_abort 'Expected a directory to install theme from, but found none.'
      end

      theme_name = install_from_directory source_filepath
      post_copying_changes(theme_name)
    end

    def copy_theme_portions source_filepath, file_mappings
      file_mappings.each do |src_dir, dest_prefix|
        Dir["#{source_filepath}/#{src_dir}/**/*"].each do |src|
          dest = src.sub("#{source_filepath}", dest_prefix).sub(/^\//, '')
          if File.file?(src) && !override?(dest) && !system_file?(src)
            Utils.copy_ensuring_directory_exists(src, dest)
          end
        end
      end
    end

    def install_from_directory source_filepath
      copy_theme_portions source_filepath, [
        ['controllers', 'app'],
        ['helpers', 'app'],
        ['layouts', 'app/views'],
        ['stylesheets', 'app/assets'],
        ['javascripts', 'app/assets'],
        ['doc', ''],
        ['images', 'app/assets'],
        ['mailers', 'app'],
        ['views', 'app'],
        ['fonts', 'app/assets'],
        ['vendor', ''],
      ]

      logger.warn 'Done installing.'
      return Utils.read_file(File.join(source_filepath, 'theme_name')).chomp
    end

    def post_copying_changes theme_name
      remove_unwanted_public_files
      create_railsthemes_demo_routes
      add_needed_gems
      Utils.set_layout_in_application_controller theme_name
      add_to_asset_precompilation_list theme_name
      comment_out_formtastic_if_user_does_not_use_formtastic theme_name
    end

    def remove_unwanted_public_files
      ['index', '404', '422', '500'].each do |filename|
        Utils.remove_file "public/#{filename}.html"
      end
    end

    def basic_route_lines
      output = <<-EOS

  ### Begin RailsThemes basic generated routes ###

  # Routes to RailsThemes Theme Example markup:
  namespace :railsthemes do
    match '/' => 'railsthemes#index', :via => [:get]
    match '/:action', :controller => :railsthemes, :via => [:get, :post]
  end

  # This is magical routing for errors (instead of using the static markup in
  # public/*.html)
  match '/403' => 'railsthemes_errors#403_forbidden', :via => [:get]
  match '/404' => 'railsthemes_errors#404_not_found', :via => [:get]
  match '/500' => 'railsthemes_errors#500_internal_server_error', :via => [:get]

  ### End RailsThemes basic generated routes ###
      EOS
      output.split("\n")
    end

    def create_railsthemes_demo_routes
      lines = Utils.lines('config/routes.rb')
      lines_to_insert = []

      if lines.grep(/Begin RailsThemes basic generated routes/).count == 0
        lines_to_insert += basic_route_lines
      end

      if lines.grep(/^\s*root /).count == 0
        lines_to_insert << '  root :to => "railsthemes/railsthemes#index"'
      end

      logger.warn 'Creating basic RailsThemes routes...'
      Utils.insert_into_routes_file! lines_to_insert
      logger.warn 'Done creating basic RailsThemes routes.'
    end

    # General assumption is `bundler check` is always clean prior to installation (via ensurer),
    # so if the gemspecs are in the Gemfile.lock, then the gem is in the Gemfile
    def add_needed_gems
      installed_gems = Utils.gemspecs.map(&:name)
      %w(
        sass
        jquery-rails
        jquery-ui-rails
        coderay
      ).each do |gemname|
        Utils.add_gem_to_gemfile gemname unless installed_gems.include?(gemname)
      end

      add_compass_rails_gem installed_gems
      add_zurb_foundation_gem installed_gems
      add_turbo_sprockets_gem installed_gems
    end

    def add_compass_rails_gem installed_gems
      unless installed_gems.include?('compass-rails')
        if Gem::Version.new(GemfileUtils.rails_version) < Gem::Version.new('4.0.0')
          Utils.add_gem_to_gemfile('compass-rails', :group => 'assets')
        else
          # see http://stackoverflow.com/questions/17341042, compass-rails + Rails 4 issues
          Utils.add_gem_to_gemfile('compass-rails', :version => '~> 2.0.alpha.0')
        end
      end
    end

    def add_zurb_foundation_gem installed_gems
      unless installed_gems.include?('zurb-foundation')
        if Gem::Version.new(GemfileUtils.rails_version) < Gem::Version.new('4.0.0')
          Utils.add_gem_to_gemfile('zurb-foundation', :version => '~> 4.0', :group => 'assets')
        else
          Utils.add_gem_to_gemfile('zurb-foundation', :version => '~> 4.0')
        end
      end
    end

    def add_turbo_sprockets_gem installed_gems
      if Gem::Version.new(GemfileUtils.rails_version) < Gem::Version.new('4.0.0')
        unless installed_gems.include?('turbo-sprockets-rails3')
          Utils.add_gem_to_gemfile('turbo-sprockets-rails3', :group => 'assets')
        end
      end
    end

    def add_to_asset_precompilation_list theme_name
      config_lines = Utils.lines('config/environments/production.rb')
      count = config_lines.grep(/^\s*config.assets.precompile\s*\+=\s*%w\(\s*railsthemes_#{theme_name}\.js\s+railsthemes_#{theme_name}\.css\s*\)$/).count
      if count == 0 # precompile line we want not found, add it
        added = false # only want to add the new line once
        Utils.safe_write('config/environments/production.rb') do |f|
          config_lines.each do |line|
            f.puts line
            if !added && (line =~ /Precompile additional assets/ || line =~ /config\.assets\.precompile/)
              f.puts "  config.assets.precompile += %w( railsthemes_#{theme_name}.js railsthemes_#{theme_name}.css )"
              f.puts "  config.assets.precompile += %w( coderay.css )"
              added = true
            end
          end
        end
      end
    end

    def comment_out_formtastic_if_user_does_not_use_formtastic theme_name
      return if (Utils.gemspecs.map(&:name) & ['formtastic']).count > 0
      filename = "app/assets/stylesheets/railsthemes_#{theme_name}.css"
      Utils.safe_read_and_write(filename) do |lines, f|
        lines.each do |line|
          if line =~ /\*= require formtastic/
            f.puts ' * require formtastic'
          else
            f.puts line
          end
        end
      end
    end

    private

    def override? dest
      (dest =~ /overrides/ || dest =~ /_header_navigation/) && File.exists?(dest)
    end

    def system_file? src
      File.basename(src)[0,1] == '.' # remove any pesky hidden files that crept into the archive
    end
  end
end
