module WebsiteTokenHelper
  def auth_token_params
    @auth_token_params ||= begin
      token = request.headers['X-Auth-Token']
      return {} if token.blank?

      decoded = ::Widget::TokenService.new(token: token).decode_token
      decoded.is_a?(Hash) ? decoded : {}
    rescue JWT::ExpiredSignature => e
      Rails.logger.warn "Widget token expired: #{e.message}"
      {}
    rescue JWT::DecodeError => e
      Rails.logger.warn "Widget token decode error: #{e.message}"
      {}
    rescue StandardError => e
      Rails.logger.error "Widget token error: #{e.class} - #{e.message}"
      {}
    end
  end

  def set_web_widget
    @web_widget = ::Channel::WebWidget.find_by!(website_token: permitted_params[:website_token])
    token = request.headers['X-Auth-Token']
    if token.present? && enforce_widget_token_validation?
      return unless validate_widget_token!(token)
    end

    token_inbox_id = auth_token_params[:inbox_id]
    if enforce_widget_token_validation? && token_inbox_id.present? && token_inbox_id.to_s != @web_widget.inbox.id.to_s
      render json: { error: 'Invalid token for this widget' }, status: :unauthorized and return
    end
  end

  def set_contact
    token = request.headers['X-Auth-Token']
    if token.present?
      return unless validate_widget_token!(token)
    end

    token_inbox_id = auth_token_params[:inbox_id]

    if token_inbox_id.blank?
      render json: { error: 'Invalid token: missing inbox_id' }, status: :unauthorized and return
    end

    unless token_inbox_id.to_s == @web_widget.inbox.id.to_s
      render json: { error: 'Invalid token for this widget' }, status: :unauthorized and return
    end

    @contact_inbox = @web_widget.inbox.contact_inboxes.find_by(
      source_id: auth_token_params[:source_id]
    )
    @contact = @contact_inbox&.contact

    unless @contact
      render json: { error: 'Contact not found' }, status: :unauthorized and return
    end

    Current.contact = @contact
  end

  def permitted_params
    params.permit(:website_token)
  end

  def enforce_widget_token_validation?
    true
  end

  def validate_widget_token!(token)
    ::Widget::TokenService.new(token: token).decode_token
    true
  rescue JWT::ExpiredSignature
    render json: { error: 'Token expired', code: 'TOKEN_EXPIRED' }, status: :unauthorized
    false
  rescue JWT::DecodeError => e
    error_message = e.message.downcase
    code = error_message.include?('missing expiration') ? 'INVALID_TOKEN' : 'INVALID_TOKEN'
    render json: { error: 'Invalid token format', code: code }, status: :unauthorized
    false
  rescue StandardError => e
    Rails.logger.error "Unexpected error validating token: #{e.class} - #{e.message}"
    render json: { error: 'Invalid token', code: 'INVALID_TOKEN' }, status: :unauthorized
    false
  end
end
