module GoogleConcern
  extend ActiveSupport::Concern

  def google_client
    app_id = GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_ID', nil)
    app_secret = GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_SECRET', nil)

    ::OAuth2::Client.new(app_id, app_secret, {
                           site: 'https://oauth2.googleapis.com',
                           authorize_url: 'https://accounts.google.com/o/oauth2/auth',
                           token_url: 'https://accounts.google.com/o/oauth2/token'
                         })
  end

  # Generates a signed JWT token for Google integration
  #
  # @param identifier [String] The identifier to encode in the token
  # @return [String, nil] The encoded JWT token or nil if client secret is missing
  def generate_google_token(identifier)
    return if client_secret.blank?

    JWT.encode(token_payload(identifier), client_secret, 'HS256')
  rescue StandardError => e
    Rails.logger.error("Failed to generate Google token: #{e.message}")
    nil
  end

  # Verifies and decodes a Google JWT token
  #
  # @param token [String] The JWT token to verify
  # @return [String, nil] The identifier from the token or nil if invalid
  def verify_google_token(token)
    return if token.blank? || client_secret.blank?

    decode_token(token, client_secret)
  end

  private

  def token_payload(identifier)
    {
      sub: identifier,
      iat: Time.current.to_i
    }
  end

  def client_secret
    @client_secret ||= GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_SECRET', nil)
  end

  def decode_token(token, secret)
    JWT.decode(token, secret, true, {
                 algorithm: 'HS256',
                 verify_expiration: true
               }).first['sub']
  rescue StandardError => e
    Rails.logger.error("Unexpected error verifying Google token: #{e.message}")
    nil
  end

  def base_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
  end
end
