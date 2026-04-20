module OauthAccountHelper
  extend ActiveSupport::Concern
  include Doorkeeper::Rails::Helpers

  private

  def ensure_oauth_token
    # Ensure we have a valid OAuth token
    return render_unauthorized('OAuth token required') unless oauth_token_present?

    # Validate the OAuth application
    oauth_application = doorkeeper_token.application
    return render_unauthorized('Invalid OAuth application') unless oauth_application

    true
  end

  def oauth_token_present?
    request.headers['Authorization']&.start_with?('Bearer ') &&
      request.headers[:api_access_token].blank? &&
      request.headers[:HTTP_API_ACCESS_TOKEN].blank?
  end

  def render_unauthorized(message = 'Unauthorized')
    render json: { error: message }, status: :unauthorized
  end
end
