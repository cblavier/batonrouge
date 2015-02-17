require 'sinatra'
require 'newrelic_rpm'

post '/' do
  bot.handle_item(params)
end

get '/' do
  "Hello World!"
end