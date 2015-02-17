require 'sinatra'
require "sinatra/reloader" if development?
require 'newrelic_rpm'
require 'redis'
require 'slackbotsy'

set :redis_url, ENV.fetch('REDIS_URL') { 'redis://localhost'}
set :redis_set, 'scores'

set :slack_channel,          ENV.fetch('SLACK_CHANNEL')           { 'test'}
set :slack_bot_name,         ENV.fetch('BOT_NAME')                { 'Baton Rouge' }
set :slack_incoming_webhook, ENV.fetch('SLACK_INCOMING_WEBHOOK')  { :missing_slack_incoming_webhook }
set :slack_outgoing_token,   ENV.fetch('SLACK_OUTGOING_TOKEN')    { :missing_slack_outgoing_token }

post '/' do
  check_authorization(params['token'])
  case params['text']
  when /^\s*help\s*$/;                        print_help
  when /^\s*ranking\s*$/;                     print_ranking
  when /^\s*remove\s*(\w+)\s*$/;              remove_user($1)    { |user| print("#{user} n'est plus dans le classement") }
  when /^\s*@?(\w+)\s*((?:-|\+)?\d+)?\s*$/;   incr_score($1, $2) { |user, score| print("#{user} a maintenant #{x(score, 'baton rouge')}") }
  else                                        print("Commande inconnue")
  end
end

def check_authorization(token)
  if token != settings.slack_outgoing_token
    error 403 do
      'Invalid token'
    end
  end
end

def print_help
  <<-eos
/batonrouge [username]           Donne un batonrouge à un utilisateur
/batonrouge [username] -1        Retire un batonrouge à un utilisateur
/batonrouge remove [username]    Retire un utilisateur du classement
/batonrouge ranking              Affiche le classement
/batonrouge help                 Affiche ce message
eos
end

def incr_score(user, count = 1)
  new_score = (redis.zincrby settings.redis_set, count.to_i, user).to_i
  if new_score < 0
    redis.zadd settings.redis_set, 0, user
    new_score = 0
  end
  yield(user, new_score) if block_given?
end

def remove_user(user)
  redis.zrem settings.redis_set, user
  yield(user) if block_given?
end

def print_ranking
  scores = redis.zscan(settings.redis_set, 0)[1].reverse
  ranking_text = scores.map {|score| "#{score[0]}: #{x(score[1].to_i, 'baton rouge')}" }
  print ranking_text.join("\n").concat("\n")
end

def print(text)
  if settings.development?
    puts text
  elsif settings.production?
    bot.say text
  end
  text
end

def x(n, singular, plural=nil)
  if (0..1).include?(n)
    "#{n} #{singular}"
  elsif plural
    "#{n} #{plural}"
  else
    "#{n} #{singular.split(' ').join('s ')}s"
  end
end

def redis
  @redis ||= Redis.new(url: settings.redis_url)
end

def bot
  @bot ||= Slackbotsy::Bot.new({
    'channel'          => settings.slack_channel,
    'name'             => settings.slack_bot_name,
    'incoming_webhook' => settings.slack_incoming_webhook,
    'outgoing_token'   => settings.slack_outgoing_token
  })
end