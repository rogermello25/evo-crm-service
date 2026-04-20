class Shopify::CallbacksController < ApplicationController
  include Shopify::IntegrationHelper

  def show
    @response = oauth_client.auth_code.get_token(
      params[:code],
      redirect_uri: '/shopify/callback'
    )

    handle_response
  rescue StandardError => e
    Rails.logger.error("Shopify callback error: #{e.message}")
    redirect_to "#{ENV.fetch('FRONTEND_URL', nil)}?error=true"
  end

  private

  def handle_response
    Hook.create!(
      app_id: 'shopify',
      access_token: parsed_body['access_token'],
      status: 'enabled',
      reference_id: params[:shop],
      settings: {
        scope: parsed_body['scope']
      }
    )

    redirect_to shopify_integration_url
  end

  def parsed_body
    @parsed_body ||= @response.response.parsed
  end

  def oauth_client
    OAuth2::Client.new(
      client_id,
      client_secret,
      {
        site: "https://#{params[:shop]}",
        authorize_url: '/admin/oauth/authorize',
        token_url: '/admin/oauth/access_token'
      }
    )
  end

  def shopify_integration_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/settings/integrations/shopify"
  end
end
