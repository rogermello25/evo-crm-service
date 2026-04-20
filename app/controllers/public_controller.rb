# TODO: we should switch to ActionController::API for the base classes
# One of the specs is failing when I tried doing that, lets revisit in future
class PublicController < ActionController::Base
  include RequestExceptionHandler
  skip_before_action :verify_authenticity_token, raise: false

  private

  def ensure_custom_domain_request
    # Portals removed - custom domain validation no longer needed
    # Custom domains should be handled at reverse proxy/load balancer level
  end
end
