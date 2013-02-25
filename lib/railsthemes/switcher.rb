module Railsthemes
  class Switcher
    include Railsthemes::Logging

    def list
      dirs = Dir['app/assets/stylesheets/railsthemes_*'].inject([]) do |accum, filepath|
        accum << filepath if File.directory?(filepath) ; accum
      end

      if dirs.empty?
        Logging.logger.warn 'There are currently no RailsThemes themes installed.'
      else
        Logging.logger.warn 'RailsThemes themes currently installed:'
        dirs.each do |dir|
          theme_name = File.basename(dir).gsub(/^railsthemes_/, '')
          Logging.logger.warn " - #{theme_name}"
        end
      end
    end
  end
end
