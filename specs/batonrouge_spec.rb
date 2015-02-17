require File.expand_path "../spec_helper.rb", __FILE__

describe "Baton Rouge" do

  let(:redis_set) { "test_scores" }
  let(:redis)     { app.send(:redis) }

  let(:user)      { "foo" }

  before do
    app.set :redis_set, redis_set
    app.set :slack_outgoing_token, nil
    redis.del(redis_set)
  end

  describe "authorization" do

    it "returns 200 if correct token" do
      app.set :slack_outgoing_token, "ACTUAL_TOKEN"
      post "/", token: "ACTUAL_TOKEN"
      expect(last_response).to be_ok
    end

    it "returns 403 if wrong token" do
      app.set :slack_outgoing_token, "ACTUAL_TOKEN"
      post "/", token: "WRONG_TOKEN"
      expect(last_response.status).to be(403)
    end

  end

  describe "help" do

    it "prints help" do
      post "/", text: "help"
      expect(last_response).to be_ok
      expect(last_response.body).to_not be_empty
    end

  end

  describe "give batonrouge" do

    it "gives 1 batonrouge" do
      Sinatra::Application.any_instance.expects(:print).with("#{user} a maintenant 1 baton rouge")
      post "/", text: "#{user} 1"
      expect(last_response).to be_ok
    end

    it "gives 5 batonrouge" do
      Sinatra::Application.any_instance.expects(:print).with("#{user} a maintenant 5 batons rouges")
      post "/", text: "#{user} 5"
      expect(last_response).to be_ok
    end

    context "with existing score" do

      let(:score) { 5 }

      before do
        redis.zadd redis_set, score, user
      end

      it "removes batonrouges" do
        Sinatra::Application.any_instance.expects(:print).with("#{user} a maintenant #{score - 2} batons rouges")
        post "/", text: "#{user} -2"
        expect(last_response).to be_ok
      end

      it "prevents score to go below 0" do
        Sinatra::Application.any_instance.expects(:print).with("#{user} a maintenant 0 baton rouge")
        post "/", text: "#{user} -10"
        expect(last_response).to be_ok
      end

    end

  end

  describe "removes user" do

    before do
      redis.zadd redis_set, rand(10), user
    end

    it "removes user" do
      Sinatra::Application.any_instance.expects(:print).with("#{user} n'est plus dans le classement")
      post "/", text: "remove #{user}"
      expect(last_response).to be_ok
      expect(redis.zscore redis_set, user).to be_nil
    end

  end

  describe "ranking" do

    let(:other_user)       { "bar" }
    let(:yet_another_user) { "fizz" }

    before do
      redis.zadd redis_set, 2, other_user
      redis.zadd redis_set, 0, yet_another_user
      redis.zadd redis_set, 5, user

    end

    it "prints ranking" do
      expectaction = <<-EOS
#{user}: 5 batons rouges
#{other_user}: 2 batons rouges
#{yet_another_user}: 0 baton rouge
EOS
      Sinatra::Application.any_instance.expects(:print).with(expectaction)
      post "/", text: "ranking"
      expect(last_response).to be_ok
    end

  end


end