class OauthController < ApplicationController
  include Doorkeeper::Rails::Helpers
  before_action :doorkeeper_authorize!, only: [:token_info]

  def callback
    # Callback para aplicações OAuth após autorização
    if params[:error]
      render_oauth_error
    elsif params[:code]
      render_oauth_success
    else
      render_oauth_fallback
    end
  end

  def test
    # Página de teste OAuth
    render plain: 'OAuth test page not available'
  end

  # RFC 7591 - Dynamic Client Registration
  def register
    begin
      registration_data = params.permit(
        :client_name,
        :client_id,
        :client_secret,
        :scope,
        :token_endpoint_auth_method,
        redirect_uris: [],
        grant_types: [],
        response_types: []
      )

      # Validações básicas
      if registration_data[:client_name].blank?
        return render json: {
          error: 'invalid_client_metadata',
          error_description: 'client_name is required'
        }, status: :bad_request
      end

      # Gerar client_id se não fornecido
      client_id = registration_data[:client_id].presence || SecureRandom.uuid

      # Gerar client_secret se não fornecido
      client_secret = registration_data[:client_secret].presence || Doorkeeper::OAuth::Helpers::UniqueToken.generate

      # Verificar se client_id já existe
      if OauthApplication.find_by(uid: client_id)
        return render json: {
          error: 'invalid_client_metadata',
          error_description: 'client_id already exists'
        }, status: :bad_request
      end

      # Configurações padrão
      redirect_uris = registration_data[:redirect_uris] || []
      grant_types = registration_data[:grant_types] || ['authorization_code', 'refresh_token']
      response_types = registration_data[:response_types] || ['code']
              scopes = registration_data[:scope] || 'admin'

      # Determinar se é aplicação pública (PKCE) ou confidencial
      is_public_client = registration_data[:token_endpoint_auth_method] == 'none'

      # Create OAuth application
      application = OauthApplication.create!(
        name: registration_data[:client_name],
        uid: client_id,
        secret: is_public_client ? nil : client_secret, # Apps públicas não precisam de secret
        redirect_uri: redirect_uris.join("\n"),
        scopes: scopes,
        trusted: false, # Apps registradas dinamicamente não são trusted por padrão
        confidential: !is_public_client # Apps públicas são não-confidenciais
      )

      # Resposta RFC 7591
      response_data = {
        client_id: application.uid,
        client_id_issued_at: application.created_at.to_i,
        client_name: application.name,
        redirect_uris: redirect_uris,
        grant_types: grant_types,
        response_types: response_types,
        token_endpoint_auth_method: registration_data[:token_endpoint_auth_method] || 'client_secret_post',
        scope: scopes
      }

      # Adicionar client_secret apenas se não for aplicação pública
      unless is_public_client
        response_data[:client_secret] = application.secret
        response_data[:client_secret_expires_at] = 0 # 0 = nunca expira
      end

      Rails.logger.info "✅ RFC 7591: Created application #{application.name} with client_id=#{client_id} (no account binding)"

      render json: response_data, status: :created

    rescue ActiveRecord::RecordInvalid => e
      render json: {
        error: 'invalid_client_metadata',
        error_description: e.message
      }, status: :bad_request
    rescue => e
      Rails.logger.error "❌ RFC 7591 Registration Error: #{e.message}"
      render json: {
        error: 'server_error',
        error_description: 'Internal server error during registration'
      }, status: :internal_server_error
    end
  end

  # Endpoint para inspecionar token OAuth
  def token_info
    token = doorkeeper_token
    application = token.application
    user = User.find(token.resource_owner_id)

    render json: {
      token: {
        token: token.token,
        scopes: token.scopes.to_a,
        expires_in: token.expires_in,
        created_at: token.created_at,
        revoked: token.revoked?
      },
      application: {
        id: application.id,
        name: application.name,
        uid: application.uid,
        trusted: application.trusted
      },
      user: {
        id: user.id,
        email: user.email,
        name: user.name
      }
    }
  end

  # RFC 8414 - OAuth 2.0 Authorization Server Metadata
  def oauth_metadata
    backend_url = request.base_url
    frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:5173')

    render json: {
      issuer: backend_url,
      # IMPORTANTE: authorization_endpoint aponta para o backend que redireciona para o frontend
      authorization_endpoint: "#{backend_url}/oauth/authorize",
      token_endpoint: "#{backend_url}/oauth/token",
      registration_endpoint: "#{backend_url}/oauth/register",
      revocation_endpoint: "#{backend_url}/oauth/revoke",
      introspection_endpoint: "#{backend_url}/oauth/introspect",
      userinfo_endpoint: "#{backend_url}/oauth/token_info",
      response_types_supported: ['code'],
      grant_types_supported: ['authorization_code', 'client_credentials', 'password', 'refresh_token'],
      scopes_supported: ['admin'],
      token_endpoint_auth_methods_supported: ['client_secret_post', 'client_secret_basic'],
      code_challenge_methods_supported: ['S256'],
      service_documentation: "#{backend_url}/docs/oauth-provider-guide",
      ui_locales_supported: ['en', 'pt-BR', 'es'],
      op_policy_uri: "#{frontend_url}/privacy",
      op_tos_uri: "#{frontend_url}/terms",
      # Extensões customizadas do Evolution
      evolution_extensions: {
        dynamic_oauth_available: true,
        dynamic_client_format: 'dynamic_app_{identifier}',
        available_accounts_endpoint: "#{backend_url}/api/v1/dynamic_oauth/available_accounts",
        validate_client_endpoint: "#{backend_url}/api/v1/dynamic_oauth/validate_client",
        api_base_url: "#{backend_url}/api/v1",
        # URLs específicas para UI (frontend)
        frontend_base_url: frontend_url,
        authorization_ui: "#{frontend_url}/auth",
        oauth_callback_ui: "#{frontend_url}/oauth/callback"
      }
    }
  end

  # RFC 8707 - OAuth 2.0 Resource Registration
  def oauth_protected_resource
    backend_url = request.base_url

    render json: {
      resource: backend_url,
      authorization_servers: [backend_url],
      scopes_supported: ['admin'],
      bearer_methods_supported: ['header', 'query'],
      resource_documentation: "#{backend_url}/api/docs",

      # RFC 9728 compliant protected resource metadata
      protected_resources: [
        {
          resource: "#{backend_url}/api/v1",
          scopes: ['admin'],
          description: "Evolution CRM API"
        },
        {
          resource: "#{backend_url}/mcp",
          scopes: ['admin'],
          description: "MCP Server Endpoints",
          bearer_methods_supported: ['header', 'query']
        }
      ],

      # Extensões para API Evolution
      evolution_extensions: {
        api_base_url: "#{backend_url}/api/v1",
        mcp_endpoint: "#{backend_url}/mcp/sse",
        mcp_transport: 'sse',
        mcp_version: '1.0.0',
        mcp_authentication_note: "For SSE connections, use ?access_token=<token> query parameter if Authorization header is not supported by proxy"
      }
    }
  end

  private

  def render_oauth_error
    render json: {
      error: params[:error],
      description: params[:error_description]
    }, status: :bad_request
  end

  def render_oauth_success
    render json: {
      authorization_code: params[:code],
      state: params[:state],
      message: 'Authorization successful. Use this code to exchange for access token.'
    }
  end

  def render_oauth_fallback
    render json: {
      error: 'no_code',
      message: 'No authorization code received'
    }, status: :bad_request
  end


end
