require 'rubygems'
require 'bundler/setup'
require 'logger'
require 'fakefs/spec_helpers'
require 'fakeweb'

RSpec.configure do |config|
  config.mock_with :rr
  config.include FakeFS::SpecHelpers
end
