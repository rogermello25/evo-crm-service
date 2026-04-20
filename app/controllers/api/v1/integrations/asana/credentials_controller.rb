# frozen_string_literal: true

class Api::V1::Integrations::Asana::CredentialsController < Api::ServiceController
  # Service-authenticated endpoint to fetch Asana OAuth credentials
  # Used by evo-ai-processor to get credentials from global config
  # Requires X-Service-Token header for authentication

  def show
    success_response(data: asana_credentials, message: 'Asana credentials retrieved successfully')
  end

  private

  def asana_credentials
    {
      asana_client_id: GlobalConfigService.load('ASANA_OAUTH_CLIENT_ID', nil),
      asana_client_secret: GlobalConfigService.load('ASANA_OAUTH_CLIENT_SECRET', nil),
      asana_redirect_uri: GlobalConfigService.load('ASANA_OAUTH_REDIRECT_URI', nil)
    }
  end
end

