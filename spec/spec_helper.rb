require 'rubygems'
require 'bundler/setup'
require 'logger'
require 'fakefs/spec_helpers'
require 'fakeweb'
require 'rr'
require 'railsthemes'

LOGFILE_NAME = 'railsthemes.log'

RSpec.configure do |config|
  config.mock_with :rr
  config.include FakeFS::SpecHelpers

  config.before :suite do
    File.delete(LOGFILE_NAME) if File.exists?(LOGFILE_NAME)
    setup_logger
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
  unless File.exist?('Gemfile')
    File.open('Gemfile', 'w') do |f|
      f.puts "source :rubygems"
    end
  end

  File.open('Gemfile', 'a') do |f|
    gems.each do |gem|
      if gem.is_a? Hash
        gem.each do |group, inner_gems|
          f.puts "group :#{group.to_s} do"
          inner_gems.each do |gemname|
            f.puts "  gem '#{gemname}'"
          end
          f.puts "end\n"
        end
      else
        f.puts "gem '#{gem.to_s}'"
      end
    end
  end

  gem_names = *gems.map do |gem|
    if gem.is_a? Hash
      gems = []
      gem.each do |group, inner_gems|
        gems += inner_gems
      end
      gems
    else
      gem
    end
  end.flatten

  File.open('Gemfile.lock', 'w') do |f|
    f.write using_gems(*gem_names)
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

def create_file filename, opts = {}
  FileUtils.mkdir_p(File.dirname(filename))
  FileUtils.touch(filename)
  File.open(filename, 'w') { |f| f.write opts[:content] } if opts[:content]
end

def filesystem
  Dir["**/*"]
end

def filesystem_should_match files_to_match
  (filesystem & files_to_match).should =~ files_to_match
end
