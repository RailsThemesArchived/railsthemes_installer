module Railsthemes
  class Switcher
    include Railsthemes::Logging

    def list
      themes = installed_themes
      if themes.empty?
        Logging.logger.warn 'There are currently no RailsThemes themes installed.'
      else
        Logging.logger.warn 'RailsThemes themes currently installed:'
        themes.each do |theme|
          Logging.logger.warn " - #{theme}"
        end
      end
    end

    def switch_to
    end

    def installed_themes
      Dir['app/assets/stylesheets/railsthemes_*'].inject([]) do |accum, filepath|
        accum << File.basename(filepath).gsub(/^railsthemes_/, '') if File.directory?(filepath)
        accum
      end
    end
  end
end
