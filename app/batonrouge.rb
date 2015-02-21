require 'sinatra'
require "sinatra/reloader" if development?
require 'newrelic_rpm'
require 'redis'

require_relative '../lib/slack_api.rb'
require_relative '../lib/game.rb'

set :redis_url,                 ENV.fetch('REDIS_URL')               { 'redis://localhost'}
set :redis_scores_key,          'scores'
set :redis_members_key,         'team_members'
set :redis_members_expiration,  3600

set :slack_channel,             ENV.fetch('SLACK_CHANNEL')           { 'test'}
set :slack_bot_name,            ENV.fetch('BOT_NAME')                { 'Baton Rouge' }
set :slack_incoming_webhook,    ENV.fetch('SLACK_INCOMING_WEBHOOK')  { :missing_slack_incoming_webhook }
set :slack_outgoing_token,      ENV.fetch('SLACK_OUTGOING_TOKEN')    { :missing_slack_outgoing_token }
set :slack_api_token,           ENV.fetch('SLACK_API_TOKEN')         { :missing_slack_api_token }

post '/' do
  check_authorization(params['token'])
  current_user = params['user_name']
  case params['text']
  when /^\s*help\s*$/
    help_text
  when /^\s*ranking\s*$/
    slack_api.say(game.ranking)
  when /^\s*remove\s*@?(\w+)\s*$/
    game.remove_user($1)
    "#{$1} n'est plus dans le classement"
  when /^\s*@?(\w+)\s*((?:-|\+)?\d+)?\s*$/
    user_to_award = $1
    inc = Integer($2) rescue 1
    if team_member?(user_to_award)
      give_baton_rouge(current_user, user_to_award, inc)
    else
      "Désolé, #{user_to_award} ne fait pas partie de l'équipe"
    end
  else
    "Commande invalide"
  end
end

# This endpoint is for newrelic.
# Newrelic will frequently ping the app, making our Heroku worker always awaken.
get '/ping' do
  'pong'
end

def check_authorization(token)
  if token != settings.slack_outgoing_token
    error 403 do
      'Invalid token'
    end
  end
end

def team_member?(username)
  slack_api.team_members.include?(username)
end

def give_baton_rouge(current_user, user_to_award, inc)
  game.incr_score(user_to_award, inc) do |score|
    text = if inc && inc < 0
      "Ouf, #{current_user} a retiré #{x(-inc, 'baton')} à #{user_to_award}. "
    else
      "Oh! #{current_user} a donné #{x(inc, 'baton')} à #{user_to_award}. "
    end
    text.concat("#{user_to_award} a maintenant #{x(score, 'baton rouge')}")
    slack_api.say text
  end
end

def help_text
  <<-eos
/batonrouge [username] - Donne un batonrouge à un utilisateur
/batonrouge [username] -1 - Retire un batonrouge à un utilisateur
/batonrouge remove [username] - Retire un utilisateur du classement
/batonrouge ranking - Affiche le classement
/batonrouge help - Affiche cette aide
eos
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

def game
  @game ||= Game.new(settings, redis)
end

def slack_api
  @slack_api ||= SlackApi.new(settings, redis)
end

def redis
  @redis ||= Redis.new(url: settings.redis_url)
end
