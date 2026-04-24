class RoomChannel < ApplicationCable::Channel
  def subscribed
    CrmLogger.websocket.info "subscription requested user_id=#{params[:user_id]}"
    @current_user = resolve_current_user
    ensure_stream
    update_subscription
    broadcast_presence
    CrmLogger.websocket.info "subscription successful user_id=#{@current_user.id}"
  rescue ActiveRecord::RecordNotFound => e
    CrmLogger.websocket.warn "subscription rejected: #{e.class} #{e.message}"
    reject
  rescue StandardError => e
    CrmLogger.websocket.error "subscription failed: #{e.class} #{e.message}"
    CrmLogger.websocket.error e.backtrace.join("\n")
    reject
  end

  def update_presence
    update_subscription
    broadcast_presence
  end

  private

  def broadcast_presence
    data = { users: ::OnlineStatusTracker.get_available_users }
    data[:contacts] = ::OnlineStatusTracker.get_available_contacts if @current_user.is_a? User
    ActionCable.server.broadcast(@stream_pubsub_token, { event: 'presence.update', data: data })
  end

  def ensure_stream
    stream_from @stream_pubsub_token
  end

  def update_subscription
    ::OnlineStatusTracker.update_presence(@current_user.class.name, @current_user.id)
  end

  def current_user
    @current_user
  end

  def resolve_current_user
    if params[:user_id].blank?
      contact_inbox = ContactInbox.find_by!(pubsub_token: params[:pubsub_token].to_s)
      @stream_pubsub_token = contact_inbox.pubsub_token
      return contact_inbox.contact
    end

    user = User.find_by(pubsub_token: params[:pubsub_token].to_s, id: params[:user_id])
    if user.present?
      @stream_pubsub_token = user.pubsub_token
      return user
    end

    verified_connection_user = connection.warden_user
    if verified_connection_user.is_a?(User) && verified_connection_user.id.to_s == params[:user_id].to_s
      CrmLogger.websocket.warn "token mismatch for user_id=#{verified_connection_user.id}; using current token"
      @stream_pubsub_token = verified_connection_user.pubsub_token
      return verified_connection_user
    end

    raise ActiveRecord::RecordNotFound, 'User not found for RoomChannel subscription'
  end
end
