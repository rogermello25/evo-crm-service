# frozen_string_literal: true

class Api::V1::Integrations::Github::CredentialsController < Api::ServiceController
  # Service-authenticated endpoint to fetch GitHub OAuth credentials
  # Used by evo-ai-processor to get credentials from global config
  # Requires X-Service-Token header for authentication

  def show
    success_response(data: github_credentials, message: 'GitHub credentials retrieved successfully')
  end

  private

  def github_credentials
    {
      github_client_id: GlobalConfigService.load('GITHUB_OAUTH_CLIENT_ID', nil),
      github_client_secret: GlobalConfigService.load('GITHUB_OAUTH_CLIENT_SECRET', nil),
      github_redirect_uri: GlobalConfigService.load('GITHUB_OAUTH_REDIRECT_URI', nil)
    }
  end
end

