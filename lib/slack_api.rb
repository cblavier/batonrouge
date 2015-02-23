require 'slackbotsy'
require 'slack'

class SlackApi

  attr_accessor :settings, :redis

  def initialize(settings, redis)
    @settings = settings
    @redis = redis
  end

  def say(text)
    if settings.development?
      puts text
    elsif settings.production?
      bot.say text
    end
    nil
  end

  # We use Redis expire command to cache the slack API call to users_list.
  # Cache timeout is settings.redis_members_expiration, in seconds.
  def team_members
    unless team_members = get_team_members_from_cache
      team_members = get_team_members_from_slack
      set_team_members_in_cache(team_members)
    end
    team_members
  end

  private

  def get_team_members_from_cache
    if team_members = redis.get(settings.redis_members_key)
      team_members.split(',')
    else
      nil
    end
  end

  def get_team_members_from_slack
    slack_api_client.users_list['members'].map{ |member| member['name'] }
  end

  def set_team_members_in_cache(team_members)
    redis.set(settings.redis_members_key, team_members.join(','))
    redis.pexpire(settings.redis_members_key, settings.redis_members_expiration)
  end

  def bot
    @bot ||= Slackbotsy::Bot.new({
      'channel'          => settings.slack_channel,
      'name'             => settings.slack_bot_name,
      'incoming_webhook' => settings.slack_incoming_webhook,
      'outgoing_token'   => settings.slack_outgoing_token
    })
  end

  def slack_api_client
    @slack_api_client ||= Slack.configure do |config|
      config.token = settings.slack_api_token
    end
    raise "Invalid slack_api_token: #{settings.slack_api_token}" unless Slack.auth_test['ok']
    Slack
  end

end