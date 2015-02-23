# Require Bundler
require 'bundler'
Bundler.require :default, :test
require 'rspec/core/rake_task'

if defined?(RSpec)
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = 'spec/**/*_spec.rb'
  end
end

# Default Task
task :default => [:spec]