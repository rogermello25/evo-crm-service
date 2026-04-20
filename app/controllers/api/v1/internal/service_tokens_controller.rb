class Api::V1::Internal::ServiceTokensController < Api::ServiceController

  # GET /api/v1/internal/service_tokens/validate
  # Validates if a service token is valid
  def validate
    token = params[:token] || service_token_from_header
    
    if ServiceToken.valid?(token)
      service_token = ServiceToken.find_by_token(token)
      render json: {
        valid: true,
        token: {
          name: service_token.name,
          description: service_token.description,
          active: service_token.active
        },
        timestamp: Time.current.iso8601
      }
    else
      render json: {
        valid: false,
        message: 'Invalid service token',
        timestamp: Time.current.iso8601
      }, status: :unauthorized
    end
  end

  # GET /api/v1/internal/service_tokens/info
  # Returns information about the current service token
  def info
    if service_authenticated?
      token = service_token_from_header
      service_token = ServiceToken.find_by_token(token)
      
      render json: {
        authenticated: true,
        token: {
          name: service_token.name,
          description: service_token.description
        },
        authentication_method: Current.authentication_method,
        timestamp: Time.current.iso8601
      }
    else
      render json: {
        authenticated: false,
        message: 'Not authenticated with service token'
      }, status: :unauthorized
    end
  end

  private

  def service_token_params
    params.permit(:token)
  end
end