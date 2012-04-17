# -*- encoding: utf-8 -*-
require File.expand_path('../lib/railsthemes/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Railsthemes"]
  gem.email         = ["anthony@railsthemes.com"]
  gem.description   = %q{railsthemes.com installer gem}
  gem.summary       = %q{Installs gems from railsthemes.com}
  gem.homepage      = "https://github.com/RailsThemes/railsthemes"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "railsthemes"
  gem.require_paths = ["lib"]
  gem.version       = Railsthemes::VERSION

  gem.add_dependency "thor"
  gem.add_dependency "rest-client"
end
