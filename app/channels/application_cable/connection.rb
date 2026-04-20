# Anonymous connections are intentionally allowed here. Two types of clients
# connect via Action Cable:
#
#   1. Agents (User) — authenticated through Warden session; warden_user is set.
#   2. Contacts (widget visitors) — have no server-side session; warden_user is nil.
#      They authenticate at the channel level via pubsub_token (see RoomChannel).
#
# Rejecting when warden_user is nil would break all widget/contact WebSocket
# connections. Channel-level authentication (RoomChannel#resolve_current_user)
# ensures that only clients with a valid pubsub_token can subscribe to streams.
class ApplicationCable::Connection < ActionCable::Connection::Base
  identified_by :warden_user

  def connect
    self.warden_user = env['warden']&.user
  rescue StandardError => e
    logger.warn "ActionCable connection user resolution failed: #{e.class} #{e.message}"
    self.warden_user = nil
  end
end
