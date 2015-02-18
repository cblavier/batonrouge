# :heavy_exclamation_mark: Baton Rouge :heavy_exclamation_mark:
A slack bot to give "batons rouges" to your teammates. In our situation we award each others with baton rouges after any awful joke!



## Technical part

batonrouge is a Sinatra app that runs seamlessly on Heroku (just add any Redis addon to you app)

You need to set following environment variables :

- REDIS_URL: uri to your redis instance
- SLACK_CHANNEL: channel where bot will print teammates scores
- SLACK_INCOMING_WEBHOOK: the webhook the bot will use to speak on Slack (configure in Slack integrations)
- SLACK_OUTGOING_TOKEN: the token passed by slack command to your app

You also need to configure a slack command (in Slack integrations) that will post to your app (on '/')
