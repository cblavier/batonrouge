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
    if team_members = redis.get(settings.redis_members_key)
      team_members = team_members.split(',')
    else
      team_members = slack_api_client.users_list['members'].map{ |member| member['name'] }
      redis.set settings.redis_members_key, team_members.join(',')
      redis.pexpire settings.redis_members_key, settings.redis_members_expiration
    end
    team_members
  end

  private

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