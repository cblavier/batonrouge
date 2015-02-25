require 'sinatra'
require "sinatra/reloader" if development?
require 'newrelic_rpm'
require 'redis'

require_relative '../lib/slack_api.rb'
require_relative '../lib/scoring.rb'

set :redis_url,                 ENV.fetch('REDIS_URL')               { 'redis://localhost'}
set :redis_scores_key,          'scores'
set :redis_members_key,         'team_members'
set :redis_members_expiration,  3_600_000 # in ms
set :redis_rate_limit,          300_000   # in ms
set :redis_rage_cooldown,       300_000   # in ms

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
    slack_api.say(scoring.ranking)
  when /^\s*remove\s*@?(\w+)\s*$/
    scoring.remove_user($1)
    "#{$1} n'est plus dans le classement"
  when /^\s*@?(\w+)\s*((?:-|\+)?\d+)?\s*$/
    user_to_award = $1
    incr = Integer($2) rescue 1
    give_baton_rouge(current_user, user_to_award, incr) do |output|
      slack_api.say output[:say] if output[:say]
      output[:return]
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

def give_baton_rouge(current_user, user_to_award, incr)
  output = if incr == 0
    {return: "Super, 0 baton rouge. Rien de mieux à faire ?"}
  elsif incr > 1
    {return: "Nan, pas plus d'un baton rouge à la fois !"}
  elsif incr < 0 && current_user == user_to_award
    {say: "LOL, #{current_user} a tenté de se retirer un baton :)", return: "Bien fait !" }
  elsif !team_member?(user_to_award)
    {return: "Désolé, #{user_to_award} ne fait pas partie de l'équipe"}
  elsif incr > 0 && scoring.rage_cooling_down?(current_user)
    {return: "Désolé, tu viens de te prendre un baton, tu vas devoir te calmer d'abord ..."}
  elsif incr > 0 && scoring.rate_limited?(current_user)
    {return: "Tout doux, calme toi un peu avant de remettre des batons"}
  else
    scoring.increment(current_user, user_to_award, incr) do |new_score|
      if incr < 0
        {say: "Ouf, #{current_user} a retiré #{x(-incr, 'baton')} à #{user_to_award}. #{user_to_award} a maintenant #{x(new_score, 'baton rouge')}"}
      else
        {say: "Oh! #{current_user} a donné #{x(incr, 'baton')} à #{user_to_award}. #{user_to_award} a maintenant #{x(new_score, 'baton rouge')}"}
      end
    end
  end
  yield(output) if block_given?
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

def scoring
  @scoring ||= Scoring.new(settings, redis)
end

def slack_api
  @slack_api ||= SlackApi.new(settings, redis)
end

def redis
  @redis ||= Redis.new(url: settings.redis_url)
end
