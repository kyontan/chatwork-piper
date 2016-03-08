#!/usr/bin/env ruby
# Coding: UTF-8

configure :development do
  use BetterErrors::Middleware
  BetterErrors.application_root = settings.root
end

configure do
  log_path = Pathname(settings.root) + "log"
  FileUtils.makedirs(log_path)
  logger = Logger.new("#{log_path}/#{settings.environment}.log", "daily")
  logger.instance_eval { alias :write :<< unless respond_to?(:write) }
  use Rack::CommonLogger, logger

  set :chatwork_api_root, URI("https://api.chatwork.com/v1/")
  set :chatwork_api_key, "CHATWORK_API_KEY"
  set :chatwork_default_rid, CHATWORK_DEFAULT_ROOM_ID

  set :slack_incoming_webhook, URI(SLACK_INCOMING_WEBHOOK)

  set :basic_auth_user, "BASIC_AUTH_USER"
  set :basic_auth_password, "BASIC_AUTH_PASSWORD"
end

helpers do
  def h(text)
    Rack::Utils.escape_html(text)
  end

  def protected!(user = nil, pass = nil)
    user ||= settings.basic_auth_user
    pass ||= settings.basic_auth_password

    unless authorized?(user, pass)
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?(user, pass)
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [user, pass]
  end

  def chatwork_post(room_id, body)
    logger.info "Post to Chatwork: room_id: #{room_id}, body: #{body}"
    uri = settings.chatwork_api_root + "rooms/#{room_id}/messages"

    req = Net::HTTP::Post.new(uri.path)
    req["X-ChatWorkToken"] = settings.chatwork_api_key
    req.form_data = {body: body}

    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    result = https.request(req)
  end

  def chatwork_get(room_id, get_already_read = false)
    logger.info "Get from Chatwork: room_id: #{room_id}, force: #{get_already_read}"
    uri = settings.chatwork_api_root + "rooms/#{room_id}/messages?force=#{get_already_read ? 1 : 0}"

    req = Net::HTTP::Get.new(uri)
    req["X-ChatWorkToken"] = settings.chatwork_api_key

    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    result = https.request(req)

    return { code: result.code, body: result.body }
  end

  def slack_post(payload)
    uri = settings.slack_incoming_webhook
    Net::HTTP.post_form(uri, { payload: payload.to_json })
  end
end

get "/?" do
  haml :index
end

post "/slack/outgoing" do
  protected!

  logger.info "Received Slack Outgoing webhook: `#{params}`"

  token        = params[:token]
  team_id      = params[:team_id]
  team_domain  = params[:team_domain]
  service_id   = params[:service_id]
  channel_id   = params[:channel_id]
  channel_name = params[:channel_name]
  timestamp    = params[:timestamp]
  user_id      = params[:user_id]
  user_name    = params[:user_name]
  text         = params[:text]

  if user_name == "slackbot"
    halt 200, "message from slackbot won't pipe to Chatwork"
  end

  body = "#{user_name}: #{text} (From Slack ##{channel_name})"

  chatwork_post(settings.chatwork_default_rid, body)
end

get "/chatwork/update" do
  protected!

  chatwork_room_id = params[:chatwork_room_id]
  chatwork_get_all = params[:chatwork_force] == "1"
  slack_channel    = params[:slack_channel] || "test"

  posts = chatwork_get(chatwork_room_id, chatwork_get_all)

  case posts[:code].to_i
  when 204
    halt 204, "no updates".to_json
  when 200
  else
    halt posts[:code].to_i, posts[:body].to_json
  end

  JSON.parse(posts[:body]).each do |post|
    permalink_url = "https://www.chatwork.com/#!rid#{chatwork_room_id}-#{post["message_id"]}"

    next if post["body"].include?("From Slack")

    slack_post({
      "channel": "##{slack_channel}",
      "username": post.dig("account", "name"),
      "text": "#{post["body"]} (<#{permalink_url}|Permalink>)",
      "icon_url": post.dig("account", "avatar_image_url")
    })
  end

  JSON.parse(posts[:body]).to_json
end

post "/test/chatwork" do
  protected!

  room_id = params[:room_id]
  body    = params[:body]

  chatwork_post(room_id, body)
end

post "/test/slack" do
  protected!

  request.body.rewind
  params = JSON.parse(request.body.read)

  slack_post(params)
end

get "/logs" do
  protected!

  path = Pathname(settings.root) + "./log/#{settings.environment}.log"
  send_file path
end

not_found do
  { error: "not found" }.to_json
end
