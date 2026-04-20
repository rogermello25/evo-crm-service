module Linear::IntegrationHelper
  # Generates a signed JWT token for Linear integration
  #
  # @param identifier [String] The identifier to encode in the token
  # @return [String, nil] The encoded JWT token or nil if client secret is missing
  def generate_linear_token(identifier)
    return if client_secret.blank?

    JWT.encode(token_payload(identifier), client_secret, 'HS256')
  rescue StandardError => e
    Rails.logger.error("Failed to generate Linear token: #{e.message}")
    nil
  end

  def token_payload(identifier)
    {
      sub: identifier,
      iat: Time.current.to_i
    }
  end

  # Verifies and decodes a Linear JWT token
  #
  # @param token [String] The JWT token to verify
  # @return [String, nil] The identifier from the token or nil if invalid
  def verify_linear_token(token)
    return if token.blank? || client_secret.blank?

    decode_token(token, client_secret)
  end

  private

  def client_secret
    @client_secret ||= GlobalConfigService.load('LINEAR_CLIENT_SECRET', nil)
  end

  def decode_token(token, secret)
    JWT.decode(token, secret, true, {
                 algorithm: 'HS256',
                 verify_expiration: true
               }).first['sub']
  rescue StandardError => e
    Rails.logger.error("Unexpected error verifying Linear token: #{e.message}")
    nil
  end
end
