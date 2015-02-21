class Scoring

  attr_accessor :settings, :redis

  def initialize(settings, redis)
    @settings = settings
    @redis = redis
  end

  def rage_cooling_down?(user)
    redis.get(redis_rage_cooldown_key(user))
  end

  def rate_limited?(user)
    redis.get(redis_rate_limit_key(user))
  end

  def increment(current_user, user_to_award, incr)
    new_score = increment_user_score(user_to_award, incr)
    if incr > 0
      set_rage_cooldown(user_to_award)
      set_rate_limit(current_user)
    end
    yield(new_score) if block_given?
  end

  def remove_user(user)
    redis.zrem settings.redis_scores_key, user
  end

  def ranking
    scores = redis.zscan(settings.redis_scores_key, 0)[1].reverse
    ranking_text = "Ok, voici le classement complet :\n"
    scores.each.with_index do |score, i|
      ranking_text.concat "#{i + 1} - #{score[0]}: #{x(score[1].to_i, 'baton rouge')}"
      ranking_text.concat "\n"
    end
    ranking_text
  end

  private

  def increment_user_score(user, increment)
    new_score = (redis.zincrby settings.redis_scores_key, increment, user).to_i
    if new_score < 0
      redis.zadd settings.redis_scores_key, 0, user
      new_score = 0
    end
    new_score
  end

  def set_rage_cooldown(user)
    redis.set(redis_rage_cooldown_key(user), true)
    redis.pexpire(redis_rage_cooldown_key(user), settings.redis_rage_cooldown)
  end

  def set_rate_limit(user)
    redis.set(redis_rate_limit_key(user), true)
    redis.pexpire(redis_rate_limit_key(user), settings.redis_rate_limit)
  end

  def redis_rate_limit_key(user)
    "rate_limit-#{user}"
  end

  def redis_rage_cooldown_key(user)
    "rage_cooldown-#{user}"
  end

end