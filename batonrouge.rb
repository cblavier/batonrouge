require 'sinatra'
require 'newrelic_rpm'

redis = Redis.new(url: ENV.fetch('REDISTOGO_URL') { 'localhost'})

post '/' do
  bot.handle_item(params)
end

get '/' do
  "Hello World!"
end