# frozen_string_literal: true

class Api::V1::Integrations::Linear::CredentialsController < Api::ServiceController
  # Service-authenticated endpoint to fetch Linear OAuth credentials
  # Used by evo-ai-processor to get credentials from global config
  # Requires X-Service-Token header for authentication

  def show
    success_response(data: linear_credentials, message: 'Linear credentials retrieved successfully')
  end

  private

  def linear_credentials
    {
      linear_client_id: GlobalConfigService.load('LINEAR_CLIENT_ID', nil),
      linear_client_secret: GlobalConfigService.load('LINEAR_CLIENT_SECRET', nil),
      linear_redirect_uri: GlobalConfigService.load('LINEAR_OAUTH_REDIRECT_URI', nil)
    }
  end
end

