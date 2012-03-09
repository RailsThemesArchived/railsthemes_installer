require 'rubygems'
require 'bundler/setup'
require 'fakefs/spec_helpers'

require 'railsthemes'

RSpec.configure do |config|
  config.mock_with :rr
  config.include FakeFS::SpecHelpers
end
