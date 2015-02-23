# Require Bundler
require 'bundler'
Bundler.require :default

unless Rails.env.production?
  Bundler.require :test
  require 'rspec/core/rake_task'

  if defined?(RSpec)
    RSpec::Core::RakeTask.new(:spec) do |t|
      t.pattern = 'spec/**/*_spec.rb'
    end
  end
end

# Default Task
task :default => [:spec]