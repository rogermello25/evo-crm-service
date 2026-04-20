# frozen_string_literal: true

class Api::V1::Integrations::Monday::CredentialsController < Api::ServiceController
  # Service-authenticated endpoint to fetch Monday OAuth credentials
  # Used by evo-ai-processor to get credentials from global config
  # Requires X-Service-Token header for authentication

  def show
    success_response(data: monday_credentials, message: 'Monday credentials retrieved successfully')
  end

  private

  def monday_credentials
    {
      monday_client_id: GlobalConfigService.load('MONDAY_OAUTH_CLIENT_ID', nil),
      monday_client_secret: GlobalConfigService.load('MONDAY_OAUTH_CLIENT_SECRET', nil),
      monday_redirect_uri: GlobalConfigService.load('MONDAY_OAUTH_REDIRECT_URI', nil)
    }
  end
end

