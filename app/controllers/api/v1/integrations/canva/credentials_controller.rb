# frozen_string_literal: true

class Api::V1::Integrations::Canva::CredentialsController < Api::ServiceController
  # Service-authenticated endpoint to fetch Canva OAuth credentials
  # Used by evo-ai-processor to get credentials from global config
  # Requires X-Service-Token header for authentication

  def show
    success_response(data: canva_credentials, message: 'Canva credentials retrieved successfully')
  end

  private

  def canva_credentials
    {
      canva_client_id: GlobalConfigService.load('CANVA_OAUTH_CLIENT_ID', nil),
      canva_client_secret: GlobalConfigService.load('CANVA_OAUTH_CLIENT_SECRET', nil),
      canva_redirect_uri: GlobalConfigService.load('CANVA_OAUTH_REDIRECT_URI', nil)
    }
  end
end
