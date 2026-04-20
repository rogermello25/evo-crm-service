# frozen_string_literal: true

class Api::V1::Oauth::AuthorizationController < Api::BaseController
  before_action :authenticate_user!

  def create
    client_id = params[:client_id]
    redirect_uri = params[:redirect_uri]
    scope = params[:scope] || 'admin'
    state = params[:state]
    code_challenge = params[:code_challenge]
    code_challenge_method = params[:code_challenge_method]

    unless client_id && redirect_uri
      render json: { error: 'Missing required parameters' }, status: :bad_request
      return
    end

    begin
      # Encontrar a aplicação OAuth
      application = OauthApplication.find_by(uid: client_id)
      unless application
        render json: { error: 'Invalid client_id' }, status: :not_found
        return
      end

      # Verificar se o redirect_uri é válido
      unless application.redirect_uri == redirect_uri || application.redirect_uri.blank?
        render json: { error: 'Invalid redirect_uri' }, status: :bad_request
        return
      end

      # Criar um access grant (código de autorização)
      grant_params = {
        application: application,
        resource_owner_id: current_user.id,
        expires_in: Doorkeeper.configuration.authorization_code_expires_in,
        redirect_uri: redirect_uri,
        scopes: scope
      }

      # Adicionar PKCE apenas se suportado
      if Doorkeeper::AccessGrant.column_names.include?('code_challenge')
        grant_params[:code_challenge] = code_challenge
        grant_params[:code_challenge_method] = code_challenge_method
      end

      access_grant = Doorkeeper::AccessGrant.create!(grant_params)

      # Retornar o código de autorização
      render json: {
        code: access_grant.token,
        state: state
      }

    rescue => e
      Rails.logger.error "❌ OAuth Authorization Error: #{e.message}"
      render json: { error: 'Authorization failed' }, status: :internal_server_error
    end
  end
end