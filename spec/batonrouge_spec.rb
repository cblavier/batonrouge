require File.expand_path "../spec_helper.rb", __FILE__

describe "Baton Rouge" do

  let(:redis_scores_key)    { "test_scores" }
  let(:redis_members_key)   { "test_team_members"}
  let(:redis_rate_limit)    { 0 }
  let(:redis_rage_cooldown) { 0 }
  let(:redis)               { app.send(:redis) }
  let(:user)                { "foo" }

  before do
    app.set :redis_scores_key,     redis_scores_key
    app.set :redis_members_key,    redis_members_key
    app.set :redis_rate_limit,     redis_rate_limit
    app.set :redis_rage_cooldown,  redis_rage_cooldown
    app.set :slack_outgoing_token, nil
    app.stubs(:bot).raises("bot should not be called during tests")
    app.stubs(:slack_api_client).raises("slack should not be called during tests")
    redis.del(redis_scores_key)
    redis.keys("rage_cooldown-*").each {|key| redis.del(key)}
    redis.keys("rate_limit-*").each    {|key| redis.del(key)}
  end

  describe "authorization" do

    let(:token) { "ACTUAL_TOKEN" }

    before do
      app.set :slack_outgoing_token, token
    end

    it "returns 200 if correct token" do
      post "/", token: token
      expect(last_response).to be_ok
    end

    it "returns 403 if wrong token", check_response_ok: false do
      post "/", token: "WRONG_TOKEN"
      expect(last_response.status).to be(403)
    end

  end

  describe "help" do

    it "says help" do
      post "/", text: "help"
      expect(last_response).to be_ok
      expect(last_response.body).to_not be_empty
    end

  end

  describe "give batonrouge" do

    let(:current_score) { 5 }
    let(:other_user)    { 'bar' }
    let(:inc)           { "" }
    let(:team_members)  { [user, other_user] }
    let(:command)       { post "/", text: "#{user} #{inc}", user_name: other_user }

    before do
      redis.zadd redis_scores_key, current_score, user # we set a score for user
      redis.set  redis_members_key, team_members.join(',') # we set team_members
    end

    after do
      expect(last_response).to be_ok
    end

    context "with a valid user" do

      context "with no increment" do

        it "gives 1 batonrouge" do
          expects_say("Oh! #{other_user} a donné 1 baton à #{user}. #{user} a maintenant #{current_score + 1} batons rouges")
          command
          expect(last_response.body).to be_empty
        end

      end

      context "with no increment" do

        it "gives 1 batonrouge" do
          expects_say("Oh! #{other_user} a donné 1 baton à #{user}. #{user} a maintenant #{current_score + 1} batons rouges")
          command
          expect(last_response.body).to be_empty
        end

      end

      context "with a 2 increment" do

        let(:inc) { 2 }

        it "returns an error" do
          command
          expect(last_response.body).to eq("Nan, pas plus d'un baton rouge à la fois !")
        end

      end

      context "with a -2 increment" do

        let(:inc) { -2 }

        it "removes 2 batonrouge" do
          expects_say("Ouf, #{other_user} a retiré #{-inc} batons à #{user}. #{user} a maintenant #{current_score + inc} batons rouges")
          command
          expect(last_response.body).to be_empty
        end

      end

      context "with a -10 increment" do

        let(:inc) { -10 }

        it "removes batons rouges but does not go below 0" do
          expects_say("Ouf, #{other_user} a retiré #{-inc} batons à #{user}. #{user} a maintenant 0 baton rouge")
          command
          expect(last_response.body).to be_empty
        end

      end

    end

    context "when self awarding" do

      let(:command) { post "/", text: "#{user} #{inc}", user_name: user }

      context "with no increment" do

        it "gives 1 batonrouge" do
          expects_say("Oh! #{user} a donné 1 baton à #{user}. #{user} a maintenant #{current_score + 1} batons rouges")
          command
          expect(last_response.body).to be_empty
        end

      end

      context "with a -1 increment" do

        let(:inc) { -1 }

        it "it returns a warning message" do
          expects_say("LOL, #{user} a tenté de se retirer un baton :)")
          command
          expect(last_response.body).to eq("Bien fait !")
        end

      end

    end

    context "when awarding a wrong user" do

      let(:team_members) { [] }

      it "returns a warning message" do
        command
        expect(last_response.body).to eq("Désolé, #{user} ne fait pas partie de l'équipe")
      end

    end

    context "with rage cooldown" do

      let(:redis_rage_cooldown) { 50 }

      it "needs user to wait the cooldown to timeout before giving a baton back" do
        post "/", text: "#{user} #{inc}", user_name: other_user
        expect(last_response.body).to be_empty

        post "/", text: "#{other_user} #{inc}", user_name: user
        expect(last_response.body).to eq("Désolé, tu viens de te prendre un baton, tu vas devoir te calmer d'abord ...")

        sleep(redis_rage_cooldown.fdiv(1000))
        post "/", text: "#{other_user} #{inc}", user_name: user
        expect(last_response.body).to be_empty
      end

    end

    context "with rate limit" do

      let(:redis_rate_limit) { 50 }

      it "needs user to wait the cooldown to timeout before giving a baton back" do
        post "/", text: "#{user} #{inc}", user_name: other_user
        expect(last_response.body).to be_empty

        post "/", text: "#{user} #{inc}", user_name: other_user
        expect(last_response.body).to eq("Tout doux, calme toi un peu avant de remettre des batons")

        sleep(redis_rate_limit.fdiv(1000))
        post "/", text: "#{user} #{inc}", user_name: other_user
        expect(last_response.body).to be_empty
      end

    end

  end


  describe "removes user" do

    before do
      redis.zadd redis_scores_key, rand(10), user
    end

    it "removes user" do
      post "/", text: "remove #{user}"
      expect(last_response).to be_ok
      expect(redis.zscore redis_scores_key, user).to be_nil
      expect(last_response.body).to eq("#{user} n'est plus dans le classement")
    end

  end

  describe "ranking" do

    let(:other_user)       { "bar" }
    let(:yet_another_user) { "fizz" }

    before do
      redis.zadd redis_scores_key, 2, other_user
      redis.zadd redis_scores_key, 0, yet_another_user
      redis.zadd redis_scores_key, 5, user
    end

    it "says ranking" do
      ranking_text = <<-EOS
Ok, voici le classement complet :
1 - #{user}: 5 batons rouges
2 - #{other_user}: 2 batons rouges
3 - #{yet_another_user}: 0 baton rouge
EOS
      expects_say ranking_text
      post "/", text: "ranking"
      expect(last_response).to be_ok
      expect(last_response.body).to be_empty
    end

  end

  describe "invalid command" do

    it "shows invalid command" do
      post "/", text: "#{user} 12 15"
      expect(last_response).to be_ok
      expect(last_response.body).to eq("Commande invalide")
    end

  end

end

def expects_say(text)
  SlackApi.any_instance.expects(:say).with(text)
end