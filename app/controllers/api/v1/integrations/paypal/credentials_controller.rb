# frozen_string_literal: true

class Api::V1::Integrations::Paypal::CredentialsController < Api::ServiceController
  # Service-authenticated endpoint to fetch PayPal OAuth credentials
  # Used by evo-ai-processor to get credentials from global config
  # Requires X-Service-Token header for authentication

  def show
    success_response(data: paypal_credentials, message: 'PayPal credentials retrieved successfully')
  end

  private

  def paypal_credentials
    {
      paypal_client_id: GlobalConfigService.load('PAYPAL_OAUTH_CLIENT_ID', nil),
      paypal_client_secret: GlobalConfigService.load('PAYPAL_OAUTH_CLIENT_SECRET', nil),
      paypal_redirect_uri: GlobalConfigService.load('PAYPAL_OAUTH_REDIRECT_URI', nil),
      paypal_environment: GlobalConfigService.load('PAYPAL_ENVIRONMENT', 'production') # Defaults to "production" if not set
    }
  end
end
