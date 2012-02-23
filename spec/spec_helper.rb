require 'rubygems'
require 'bundler/setup'

require 'railsthemes'

TESTING = true

RSpec.configure do |config|
  config.mock_with :rr
end
