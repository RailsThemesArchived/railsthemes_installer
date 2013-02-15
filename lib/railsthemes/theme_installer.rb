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
      elsif Utils.archive?(source_filepath + '.tar.gz')
        install_from_archive(source_filepath + '.tar.gz')
      else
        Safe.log_and_abort 'Expected either a directory or archive.'
      end

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
      ]

      logger.warn 'Done installing.'
      return Utils.read_file(File.join(source_filepath, 'theme_name'))
    end

    def post_copying_changes theme_name
      remove_unwanted_public_files
      create_railsthemes_demo_routes
      add_needed_gems
      set_layout_in_application_controller theme_name
      add_to_asset_precompilation_list theme_name
    end

    def remove_unwanted_public_files
      ['index', '404', '422', '500'].each do |filename|
        Utils.remove_file "public/#{filename}.html"
      end
    end

    def create_railsthemes_demo_routes
      lines = Utils.lines('config/routes.rb')
      return if lines.grep(/Begin RailsThemes basic generated routes/).count > 0

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
      logger.warn 'Creating basic RailsThemes routes...'
      Utils.insert_into_routes_file! output.split("\n")
      logger.warn 'Done creating basic RailsThemes routes.'
    end

    # General assumption is `bundler check` is always clean prior to installation (via ensurer),
    # so if the gemspecs are in the Gemfile.lock, then the gem is in the Gemfile
    def add_needed_gems
      installed_gems = Utils.gemspecs.map(&:name)
      ['sass', 'jquery-rails', 'jquery-ui-rails', 'foundation'].each do |gemname|
        Utils.add_gem_to_gemfile gemname unless installed_gems.include?(gemname)
      end
    end

    def set_layout_in_application_controller theme_name
      ac_lines = Utils.lines('app/controllers/application_controller.rb')
      count = ac_lines.grep(/^\s*layout 'railsthemes/).count
      if count == 0 # layout line not found, add it
        FileUtils.mkdir_p('app/controllers')
        File.open('app/controllers/application_controller.rb', 'w') do |f|
          ac_lines.each do |line|
            f.puts line
            f.puts "  layout 'railsthemes_#{theme_name}'" if line =~ /^class ApplicationController/
          end
        end
      elsif count == 1 # layout line found, change it if necessary
        File.open('app/controllers/application_controller.rb', 'w') do |f|
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
      count = config_lines.grep(/^\s*config.assets.precompile \+= %w\( railsthemes_#{theme_name}\.js railsthemes_#{theme_name}\.css \)$/).count
      if count == 0 # precompile line we want not found, add it
        FileUtils.mkdir_p('config/environments')
        added = false # only want to add the new line once
        File.open('config/environments/production.rb', 'w') do |f|
          config_lines.each do |line|
            f.puts line
            if !added && (line =~ /Precompile additional assets/ || line =~ /config\.assets\.precompile/)
              f.puts "config.assets.precompile += %w( railsthemes_#{theme_name}.js railsthemes_#{theme_name}.css )"
              added = true
            end
          end
        end
      end
    end

    private

    def override? dest
      dest =~ /overrides/ && File.exists?(dest)
    end

    def system_file? src
      src =~ /\/\./ # remove any pesky hidden files that crept into the archive
    end
  end
end
