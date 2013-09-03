module Railsthemes
  class GemfileUtils
    def self.rails_version gemfile_contents = nil
      gemfile_contents ||= Utils.read_file('Gemfile.lock')
      specs = Utils.gemspecs(gemfile_contents)
      rails = specs.select{ |x| x.name == 'rails' }.first
      rails.version if rails && rails.version
    end
  end
end
