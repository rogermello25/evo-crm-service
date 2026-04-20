class Oauth::ApplicationsController < ApplicationController
  # OAuth applications management is now handled by frontend
  # This controller is kept for API compatibility but HTML views are removed
  before_action :authenticate_user!
  before_action :ensure_administrator!

  def ensure_administrator!
    frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:5173')
    redirect_to "#{frontend_url}/auth", alert: I18n.t('INTEGRATION_SETTINGS.OAUTH_APPLICATIONS.ACCESS_DENIED') unless current_user&.administrator?
  end
end
