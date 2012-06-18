require 'rubygems'
require 'bundler/setup'
require 'logger'
require 'fakefs/spec_helpers'
require 'fakeweb'

RSpec.configure do |config|
  config.mock_with :rr
  config.include FakeFS::SpecHelpers

  # RSpec automatically cleans stuff out of backtraces;
  # sometimes this is annoying when trying to debug something e.g. a gem
  #config.backtrace_clean_patterns = [
  ##  /\/lib\d*\/ruby\//,
  ##  /bin\//,
  ##  /gems/,
  ##  /spec\/spec_helper\.rb/,
  ##  /lib\/rspec\/(core|expectations|matchers|mocks)/
  #]
end

FakeWeb.allow_net_connect = false
