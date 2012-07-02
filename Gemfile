source 'https://rubygems.org'

gemspec
gem 'thor'
gem 'rest-client'
gem 'launchy'
gem 'json'
# make sure you add any new dependencies in railsthemes.gemspec

group :development do
  gem 'gem-release'
  gem 'guard'
  gem 'guard-rspec'
end

group :test do
  gem 'rspec'
  gem 'rr'
  gem 'autotest'
  gem 'fakefs', :require => 'fakefs/safe', :git => 'https://github.com/RailsThemes/fakefs.git'
  gem 'fakeweb'
end
