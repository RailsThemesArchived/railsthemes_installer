module Railsthemes
  module Logging
    # Method to mix into classes
    def logger
      Logging.logger
    end

    def self.logger
      if @logger
        @logger
      else
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::WARN

        # just print out basic information, not all of the extra logger stuff
        @logger.formatter = proc { |severity, datetime, progname, msg| "#{msg}\n" }
        @logger
      end
    end

    def self.logger= logger
      @logger = logger
    end
  end
end
