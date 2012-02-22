require 'rubygems'
require 'bundler/setup'

require 'railsthemes'

ENVIRONMENT = 'test'

RSpec.configure do |config|
  config.mock_with :rr
end
