# frozen_string_literal: true

class Api::V1::Integrations::Notion::CredentialsController < Api::ServiceController
  # Service-authenticated endpoint to fetch Notion OAuth credentials
  # Used by evo-ai-processor to get credentials from global config
  # Requires X-Service-Token header for authentication

  def show
    success_response(data: notion_credentials, message: 'Notion credentials retrieved successfully')
  end

  private

  def notion_credentials
    {
      notion_client_id: GlobalConfigService.load('NOTION_OAUTH_CLIENT_ID', nil),
      notion_client_secret: GlobalConfigService.load('NOTION_OAUTH_CLIENT_SECRET', nil),
      notion_redirect_uri: GlobalConfigService.load('NOTION_OAUTH_REDIRECT_URI', nil)
    }
  end
end

