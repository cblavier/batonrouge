require 'rack/test'
require 'mocha'

# Also tried this
# Rack::Builder.parse_file(File.expand_path('../../config.ru', __FILE__))

require File.expand_path '../../app/batonrouge.rb', __FILE__

ENV['RACK_ENV'] = 'test'

module RSpecMixin
  include Rack::Test::Methods
  def app() Sinatra::Application end
end

RSpec.configure do |config|
  config.include RSpecMixin
  config.mock_with :mocha

  config.before do
    app.set :environment, 'test'
  end
end