# frozen_string_literal: true

class Api::V1::Integrations::GoogleCalendar::CredentialsController < Api::ServiceController
  # Service-authenticated endpoint to fetch Google Calendar OAuth credentials
  # Used by evo-ai-processor to get credentials from global config
  # Requires X-Service-Token header for authentication

  def show
    success_response(data: google_calendar_credentials, message: 'Google Calendar credentials retrieved successfully')
  end

  private

  def google_calendar_credentials
    {
      google_calendar_client_id: GlobalConfigService.load('GOOGLE_CALENDAR_CLIENT_ID', nil),
      google_calendar_client_secret: GlobalConfigService.load('GOOGLE_CALENDAR_CLIENT_SECRET', nil),
      google_calendar_redirect_uri: GlobalConfigService.load('GOOGLE_CALENDAR_REDIRECT_URI', nil)
    }
  end
end
