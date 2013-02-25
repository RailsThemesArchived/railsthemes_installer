module Railsthemes
  class Switcher
    include Railsthemes::Logging

    def list
      themes = installed_themes
      if themes.empty?
        logger.warn 'There are currently no RailsThemes themes installed.'
      else
        logger.warn 'RailsThemes themes currently installed:'
        themes.each do |theme|
          logger.warn " - #{theme}"
        end
      end
    end

    def switch_to theme_name
      themes = installed_themes
      if themes.include? theme_name
        Utils.set_layout_in_application_controller theme_name
      else
        logger.warn "'#{theme_name}' is not a locally installed RailsThemes theme."
      end
    end

    def installed_themes
      Dir['app/assets/stylesheets/railsthemes_*'].inject([]) do |accum, filepath|
        accum << File.basename(filepath).gsub(/^railsthemes_/, '') if File.directory?(filepath)
        accum
      end
    end
  end
end
