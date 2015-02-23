# Require Bundler
require 'bundler'
Bundler.require :default

unless ENV['RACK_ENV'] == 'production'
  Bundler.require :test
  require 'rspec/core/rake_task'

  if defined?(RSpec)
    RSpec::Core::RakeTask.new(:spec) do |t|
      t.pattern = 'spec/**/*_spec.rb'
    end
  end

  task :default => [:spec]
end

