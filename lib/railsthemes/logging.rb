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

    def self.verbose
      logger.level = Logger::INFO
      logger.info 'In verbose mode.'
    end

    def self.debug
      logger.level = Logger::DEBUG
      logger.debug 'In debug mode.'
    end
  end
end
