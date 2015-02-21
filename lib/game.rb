class Game

  attr_accessor :settings, :redis

  def initialize(settings, redis)
    @settings = settings
    @redis = redis
  end

  def incr_score(user, count)
    new_score = (redis.zincrby settings.redis_scores_key, count, user).to_i
    if new_score < 0
      redis.zadd settings.redis_scores_key, 0, user
      new_score = 0
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

end