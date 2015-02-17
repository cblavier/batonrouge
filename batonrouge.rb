require 'sinatra'
require 'newrelic_rpm'
require 'redis'

redis = Redis.new(url: ENV.fetch('REDISTOGO_URL') { 'redis://localhost'})

post '/' do
  bot.handle_item(params)
end

get '/' do
  "Hello World!"
end