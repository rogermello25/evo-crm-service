# frozen_string_literal: true

class Api::V1::Integrations::Supabase::CredentialsController < Api::ServiceController
  # Service-authenticated endpoint to fetch Supabase OAuth credentials
  # Used by evo-ai-processor to get credentials from global config
  # Requires X-Service-Token header for authentication
  #
  # Note: Supabase OAuth only requires redirect_uri, no client_id/secret needed
  # Authorization URL and MCP endpoint are hardcoded in the processor service

  def show
    success_response(data: supabase_credentials, message: 'Supabase credentials retrieved successfully')
  end

  private

  def supabase_credentials
    {
      supabase_redirect_uri: GlobalConfigService.load('SUPABASE_OAUTH_REDIRECT_URI', nil)
    }
  end
end
