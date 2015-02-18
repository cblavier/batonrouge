# :heavy_exclamation_mark: Baton Rouge :heavy_exclamation_mark:
A slack bot to give "batons rouges" to your teammates. In our situation we award each others with baton rouges after any awful joke!

{<img src="https://secure.travis-ci.org/cblavier/batonrouge.png?branch=master" />}[http://travis-ci.org/cblavier/batonrouge]

{<img src="https://codeclimate.com/github/cblavier/batonrouge.png" />}[https://codeclimate.com/github/cblavier/batonrouge]

{<img src="https://codeclimate.com/github/cblavier/batonrouge/coverage.png" />}[https://codeclimate.com/github/cblavier/batonrouge]

## User guide

On slack, use `/batonrouge help` command to get started.

## Technical part

batonrouge is a Sinatra app that runs seamlessly on Heroku (just add any Redis addon to you app)

You need to set following environment variables :

- REDIS_URL: uri to your redis instance
- SLACK_CHANNEL: channel where bot will print teammates scores
- SLACK_INCOMING_WEBHOOK: the webhook the bot will use to speak on Slack (configure in Slack integrations)
- SLACK_OUTGOING_TOKEN: the token passed by slack command to your app
- SLACK_API_TOKEN: a different token, used to fetch team members using Slack web API

You also need to configure a slack command (in Slack integrations) that will post to your app (on '/')
