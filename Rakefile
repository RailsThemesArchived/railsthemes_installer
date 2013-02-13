#!/usr/bin/env rake
require 'bundler/gem_tasks'
require 'cucumber/rake/task'
require 'rspec/core/rake_task'

Cucumber::Rake::Task.new do |t|
  t.cucumber_opts = "--format pretty"
end
task :cuc => :cucumber

RSpec::Core::RakeTask.new(:spec)
task :default => [:spec, :cucumber]
