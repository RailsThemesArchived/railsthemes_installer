source 'https://rubygems.org'

# Specify your gem's dependencies in railsthemes.gemspec
gemspec
gem 'thor'
gem 'rest-client'

group :development do
  gem 'gem-release'
  gem 'guard'
  gem 'guard-rspec'
end

# development gems
group :test do
  gem 'rspec'
  gem 'rr'
  gem 'autotest'
  gem 'fakefs', :require => 'fakefs/safe', :git => 'https://github.com/RailsThemes/fakefs.git'
  gem 'fakeweb'
end
