# frozen_string_literal: true

module DynamicOauthHelper
  def dynamic_client_id_for_identifier(identifier)
    DynamicOauthService.generate_dynamic_client_id(identifier)
  end
  
  def is_dynamic_client_id?(client_id)
    DynamicOauthService.is_dynamic_client_id?(client_id)
  end
  
  def available_dynamic_accounts(user = current_user)
    return [] unless user
    
    DynamicOauthService.available_accounts_for_user(user)
  end
  
  def build_oauth_authorization_url(client_id, redirect_uri, scope: 'admin', state: nil)
    params = {
      response_type: 'code',
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: scope
    }
    
    params[:state] = state if state.present?
    
    "#{request.base_url}/oauth/authorize?#{params.to_query}"
  end
  
  def build_dynamic_oauth_url(identifier, redirect_uri, scope: 'admin', state: nil)
    client_id = dynamic_client_id_for_identifier(identifier)
    build_oauth_authorization_url(client_id, redirect_uri, scope: scope, state: state)
  end
end