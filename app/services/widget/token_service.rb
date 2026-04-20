class Widget::TokenService
  pattr_initialize [:payload, :token]

  # Default expiration time: 24 hours
  DEFAULT_EXPIRATION_TIME = 24.hours

  def generate_token
    # Add expiration claim to payload
    token_payload = payload.dup
    expiration_time = expiration_time_from_env || DEFAULT_EXPIRATION_TIME
    token_payload[:exp] = expiration_time.from_now.to_i
    token_payload[:iat] = Time.current.to_i

    JWT.encode token_payload, secret_key, 'HS256'
  end

  def decode_token
    # First decode without expiration verification to check if exp claim exists
    decoded_token = JWT.decode(
      token, secret_key, true, algorithm: 'HS256', verify_expiration: false
    ).first.symbolize_keys

    # Check if exp claim exists
    unless decoded_token[:exp]
      raise JWT::DecodeError, 'Token missing expiration claim'
    end

    # Now verify expiration
    if decoded_token[:exp] < Time.current.to_i
      raise JWT::ExpiredSignature, 'Token expired'
    end

    decoded_token
  rescue JWT::ExpiredSignature => e
    # Re-raise expired token errors with clear message
    raise JWT::ExpiredSignature, "Token expired: #{e.message}"
  rescue JWT::DecodeError => e
    # Re-raise decode errors
    raise JWT::DecodeError, "Invalid token: #{e.message}"
  rescue StandardError => e
    # For other errors, return empty hash for backward compatibility
    # but log the error for debugging
    Rails.logger.error "Widget::TokenService decode error: #{e.class} - #{e.message}"
    {}
  end

  private

  def secret_key
    Rails.application.secret_key_base
  end

  def expiration_time_from_env
    expiration_str = ENV['WIDGET_JWT_EXPIRATION']
    return nil unless expiration_str

    # Parse formats like "24.hours", "7.days", "3600" (seconds)
    case expiration_str
    when /^(\d+)\.hours?$/
      Regexp.last_match(1).to_i.hours
    when /^(\d+)\.days?$/
      Regexp.last_match(1).to_i.days
    when /^(\d+)$/
      Regexp.last_match(1).to_i.seconds
    else
      Rails.logger.warn "Invalid WIDGET_JWT_EXPIRATION format: #{expiration_str}. Using default."
      nil
    end
  end
end
