chatwork-piper
===

Pipes messages between Slack and Chatwork

1. Requirement
  - Ruby
  - [bundler gem](http://bundler.io/)
  
2. Installation
  1. clone this repository
  2. `$ cd chatwork-piper`
  3. `$ bundle`
  4. Edit configs
  ```
  set :chatwork_api_key, "CHATWORK_API_KEY"
  set :chatwork_default_rid, CHATWORK_DEFAULT_ROOM_ID

  set :slack_incoming_webhook, URI(SLACK_INCOMING_WEBHOOK)

  set :basic_auth_user, "BASIC_AUTH_USER"
  set :basic_auth_password, "BASIC_AUTH_PASSWORD"
  ```

3. Run
`bundle exec rackup`

4. How to use?
  1. Add Incoming Webhook to Slack (and edit `app.rb`)
  2. Add Outgoing Webhook to Slack to `http://USER:PASSWORD@HOST_IP/slack/outgoing`
  3. curl `http://USER:PASSWORD@HOST_IP/chatwork/update` frequently

5. Lisence
MIT
