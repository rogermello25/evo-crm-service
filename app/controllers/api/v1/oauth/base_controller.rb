class Api::V1::Oauth::BaseController < Api::BaseController
  include SwitchLocale
  include OauthAccountHelper

  # Nossa própria autenticação OAuth (substitui a do pai)
  skip_before_action :authenticate_request!
  before_action :ensure_oauth_authentication!
  around_action :switch_locale_using_default

  private

  def ensure_oauth_authentication!
    unless oauth_token_present?
      render_unauthorized('OAuth token required. This endpoint only accepts OAuth authentication.')
      return
    end

    # Autenticar usando o método do concern parent
    authenticate_oauth_token!
  end
end
