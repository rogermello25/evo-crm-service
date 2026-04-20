# frozen_string_literal: true

class Api::V1::Integrations::GoogleSheets::CredentialsController < Api::ServiceController
  # Service-authenticated endpoint to fetch Google Sheets OAuth credentials
  # Used by evo-ai-processor to get credentials from global config
  # Requires X-Service-Token header for authentication

  def show
    success_response(data: google_sheets_credentials, message: 'Google Sheets credentials retrieved successfully')
  end

  private

  def google_sheets_credentials
    {
      google_sheets_client_id: GlobalConfigService.load('GOOGLE_SHEETS_CLIENT_ID', nil),
      google_sheets_client_secret: GlobalConfigService.load('GOOGLE_SHEETS_CLIENT_SECRET', nil),
      google_sheets_redirect_uri: GlobalConfigService.load('GOOGLE_SHEETS_REDIRECT_URI', nil)
    }
  end
end
