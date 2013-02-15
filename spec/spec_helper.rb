require 'rubygems'
require 'bundler/setup'
require 'logger'
require 'fakefs/spec_helpers'
require 'fakeweb'
require 'rr'

LOGFILE_NAME = 'railsthemes.log'

RSpec.configure do |config|
  config.mock_with :rr
  config.include FakeFS::SpecHelpers

  config.before :suite do
    File.delete(LOGFILE_NAME) if File.exists?(LOGFILE_NAME)
  end

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

def write_gemfiles_using_gems *gems
  File.open('Gemfile', 'a') do |f|
    f.puts "source :rubygems"
    gems.each do |gemname|
      f.puts "gem '#{gemname}'"
    end
  end

  File.open('Gemfile.lock', 'w') do |f|
    f.write using_gems(*gems)
  end
end

def using_gems *gems
  "GEM\nremote: https://rubygems.org/\nspecs:\n" +
    gems.map{|gem| "    #{gem}"}.join("\n") +
    "\nGEM\n  remote: https://rubygems.org/"
end

def using_gem_specs specs = {}
  lines = []
  specs.each { |name, version| lines << "    #{name} (#{version})"}
  "GEM\nremote: https://rubygems.org/\nspecs:\n" +
    lines.join("\n") +
    "\nGEM\n  remote: https://rubygems.org/"
end

def stub_tempdir
  tempdir = ''
  if OS.windows?
    tempdir = File.join('C:', 'Users', 'Admin', 'AppData', 'Local', 'Temp')
  else
    tempdir = 'tmp'
  end
  stub(Railsthemes::Utils).generate_tempdir_name { tempdir }
  tempdir
end

def setup_logger
  logger = Logger.new(LOGFILE_NAME)
  logger.info "#{self.example.description}"
  Railsthemes::Logging.logger = logger
  logger
end

def with_installer_version version, &block
  old_version = Railsthemes::VERSION
  Railsthemes.send(:remove_const, 'VERSION')
  Railsthemes.const_set('VERSION', version)

  block.call

  Railsthemes.send(:remove_const, 'VERSION')
  Railsthemes.const_set('VERSION', old_version)
end
