class Api::ServiceController < ApplicationController
  include ServiceTokenAuthConcern
  include ApiResponseHelper
  respond_to :json

  before_action :authenticate_service_token!

  private

  def render_unauthorized(message = 'Unauthorized')
    render_service_token_unauthorized(message)
  end


  def check_admin_authorization?
    # Service tokens can perform admin operations for internal services
    return true if service_authenticated?
    
    super
  end
end