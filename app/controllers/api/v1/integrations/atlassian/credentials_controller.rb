# frozen_string_literal: true

class Api::V1::Integrations::Atlassian::CredentialsController < Api::ServiceController
  # Service-authenticated endpoint to fetch Atlassian OAuth credentials
  # Used by evo-ai-processor to get credentials from global config
  # Requires X-Service-Token header for authentication

  def show
    success_response(data: atlassian_credentials, message: 'Atlassian credentials retrieved successfully')
  end

  private

  def atlassian_credentials
    {
      atlassian_client_id: GlobalConfigService.load('ATLASSIAN_OAUTH_CLIENT_ID', nil),
      atlassian_client_secret: GlobalConfigService.load('ATLASSIAN_OAUTH_CLIENT_SECRET', nil),
      atlassian_redirect_uri: GlobalConfigService.load('ATLASSIAN_OAUTH_REDIRECT_URI', nil)
    }
  end
end

