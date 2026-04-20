# frozen_string_literal: true

class Api::V1::Integrations::Hubspot::CredentialsController < Api::ServiceController
  # Service-authenticated endpoint to fetch HubSpot OAuth credentials
  # Used by evo-ai-processor to get credentials from global config
  # Requires X-Service-Token header for authentication

  def show
    success_response(data: hubspot_credentials, message: 'HubSpot credentials retrieved successfully')
  end

  private

  def hubspot_credentials
    {
      hubspot_client_id: GlobalConfigService.load('HUBSPOT_OAUTH_CLIENT_ID', nil),
      hubspot_client_secret: GlobalConfigService.load('HUBSPOT_OAUTH_CLIENT_SECRET', nil),
      hubspot_redirect_uri: GlobalConfigService.load('HUBSPOT_OAUTH_REDIRECT_URI', nil)
    }
  end
end

