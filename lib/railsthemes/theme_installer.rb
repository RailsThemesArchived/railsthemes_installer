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

      theme_name = nil
      if File.directory?(source_filepath)
        theme_name = install_from_directory source_filepath
        post_copying_changes(theme_name)
      elsif Utils.archive?(source_filepath + '.tar.gz')
        install_from_archive(source_filepath + '.tar.gz')
      else
        Safe.log_and_abort 'Expected either a directory or archive.'
      end
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
      ]

      logger.warn 'Done installing.'
      return Utils.read_file(File.join(source_filepath, 'theme_name')).chomp
    end

    def post_copying_changes theme_name
      remove_unwanted_public_files
      create_railsthemes_demo_routes
      add_needed_gems
      set_layout_in_application_controller theme_name
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
  unless Rails.env.production?
    match 'railsthemes', :controller => :railsthemes, :action => :index
    match 'railsthemes/:action', :controller => :railsthemes
  end

  # This is magical routing for errors (instead of using the static markup in
  # public/*.html)
  match '/403', :to => 'railsthemes_errors#403_forbidden'
  match '/404', :to => 'railsthemes_errors#404_not_found'
  match '/500', :to => 'railsthemes_errors#500_internal_server_error'
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
        lines_to_insert << '  root :to => "railsthemes#index"'
      end

      logger.warn 'Creating basic RailsThemes routes...'
      Utils.insert_into_routes_file! lines_to_insert
      logger.warn 'Done creating basic RailsThemes routes.'
    end

    # General assumption is `bundler check` is always clean prior to installation (via ensurer),
    # so if the gemspecs are in the Gemfile.lock, then the gem is in the Gemfile
    def add_needed_gems
      installed_gems = Utils.gemspecs.map(&:name)
      ['sass', 'jquery-rails', 'jquery-ui-rails'].each do |gemname|
        Utils.add_gem_to_gemfile gemname unless installed_gems.include?(gemname)
      end
      ['compass-rails', 'zurb-foundation'].each do |gemname|
        Utils.add_gem_to_gemfile(gemname, :group => 'assets') unless installed_gems.include?(gemname)
      end
    end

    def set_layout_in_application_controller theme_name
      ac_lines = Utils.lines('app/controllers/application_controller.rb')
      count = ac_lines.grep(/^\s*layout 'railsthemes/).count
      if count == 0 # layout line not found, add it
        Utils.safe_write('app/controllers/application_controller.rb') do |f|
          ac_lines.each do |line|
            f.puts line
            f.puts "  layout 'railsthemes_#{theme_name}'" if line =~ /^class ApplicationController/
          end
        end
      elsif count == 1 # layout line found, change it if necessary
        Utils.safe_write('app/controllers/application_controller.rb') do |f|
          ac_lines.each do |line|
            if line =~ /^\s*layout 'railsthemes_/
              f.puts "  layout 'railsthemes_#{theme_name}'"
            else
              f.puts line
            end
          end
        end
      else
        # multiple layout lines, not sure what to do here
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
      dest =~ /overrides/ && File.exists?(dest)
    end

    def system_file? src
      File.basename(src)[0,1] == '.' # remove any pesky hidden files that crept into the archive
    end
  end
end
