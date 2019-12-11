#!/usr/bin/env ruby

require 'matrix_sdk'

# A filter to simplify syncs
BOT_FILTER = {
  presence: { types: [] },
  account_data: { types: [] },
  room: {
    ephemeral: { types: [] },
    state: {
      types: ['m.room.*'],
      lazy_load_members: true
    },
    timeline: {
      types: ['m.room.message']
    },
    account_data: { types: [] }
  }
}.freeze

class MatrixBot
  def initialize(hs_url, access_token)
    @hs_url = hs_url
    @token = access_token
  end

  def run
    # Join all invited rooms
    client.on_invite_event.add_handler { |ev| client.join_room(ev[:room_id]) }
    # Read all message events
    client.on_event.add_handler('m.room.message') { |ev| on_message(ev) }

    # Run an empty sync to get to a `since` token without old data
    empty_sync = deep_copy(BOT_FILTER)
    empty_sync[:room].map { |_k, v| v[:types] = [] }
    client.sync filter: empty_sync

    loop do
      begin
        client.sync filter: BOT_FILTER
      rescue MatrixSdk::MatrixError => e
        puts e
      end
    end
  end

  def on_message(message)
    msgstr = message.content[:body]

    return unless msgstr =~ /^!ping\s*/

    msgstr.gsub!(/!ping\s*/, '')
    msgstr = " \"#{msgstr}\"" unless msgstr.empty?

    room = client.ensure_room message.room_id
    sender = client.get_user message.sender

    puts "[#{Time.now.strftime '%H:%M'}] <#{sender.id} in #{room.id}> #{message.content[:body]}"

    origin_ts = Time.at(message[:origin_server_ts] / 1000.0)
    diff = Time.now - origin_ts

    plaintext = '%<sender>s: Pong! (ping%<msg>s took %<time>u ms to arrive)'
    html = '<a href="https://matrix.to/#/%<sender>s">%<sender>s</a>: Pong! (<a href="https://matrix.to/#/%<room>s/%<event>s">ping</a>%<msg>s took %<time>u ms to arrive)'

    formatdata = {
      sender: sender.id,
      room: room.id,
      event: message.event_id,
      time: (diff * 1000).to_i,
      msg: msgstr
    }

    from_id = MatrixSdk::MXID.new(sender.id)

    eventdata = {
      body: format(plaintext, formatdata),
      format: 'org.matrix.custom.html',
      formatted_body: format(html, formatdata),
      msgtype: 'm.notice',
      pong: {
        from: from_id.homeserver,
        ms: formatdata[:time],
        ping: formatdata[:event]
      }
    }

    client.api.send_message_event(room.id, 'm.room.message', eventdata)
  end

  private

  def client
    @client ||= MatrixSdk::Client.new @hs_url, access_token: @token, client_cache: :none
  end

  def deep_copy(hash)
    Marshal.load(Marshal.dump(hash))
  end
end

if $PROGRAM_NAME == __FILE__
  raise "Usage: #{$PROGRAM_NAME} [-d] homeserver_url access_token" unless ARGV.length >= 2

  if ARGV.first == '-d'
    Thread.abort_on_exception = true
    MatrixSdk.debug!
    ARGV.shift
  end

  bot = MatrixBot.new ARGV[0], ARGV[1]
  bot.run
end
