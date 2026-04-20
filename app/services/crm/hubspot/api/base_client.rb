class Crm::Hubspot::Api::BaseClient
  include HTTParty

  class ApiError < StandardError
    attr_reader :code, :response

    def initialize(message = nil, code = nil, response = nil)
      @code = code
      @response = response
      super(message)
    end
  end

  def initialize(access_token_or_hook)
    if access_token_or_hook.is_a?(String)
      @access_token = access_token_or_hook
      @hook = nil
    else
      @hook = access_token_or_hook
      @access_token = nil
    end
    @base_uri = 'https://api.hubapi.com'
  end

  def get(path, params = {})
    full_url = URI.join(@base_uri, path).to_s

    options = {
      query: params,
      headers: headers
    }

    response = self.class.get(full_url, options)
    handle_response(response)
  end

  def post(path, params = {}, body = {})
    full_url = URI.join(@base_uri, path).to_s

    options = {
      query: params,
      headers: headers
    }

    options[:body] = body.to_json if body.present?

    response = self.class.post(full_url, options)
    handle_response(response)
  end

  def patch(path, params = {}, body = {})
    full_url = URI.join(@base_uri, path).to_s

    options = {
      query: params,
      headers: headers
    }

    options[:body] = body.to_json if body.present?

    response = self.class.patch(full_url, options)
    handle_response(response)
  end

  private

  def headers
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{current_access_token}"
    }
  end

  def current_access_token
    return @access_token if @access_token.present?
    return @hook.access_token unless @hook

    Hubspot::RefreshOauthTokenService.new(hook: @hook).access_token
  end

  def handle_response(response)
    case response.code
    when 200..299
      handle_success(response)
    else
      error_message = "HubSpot API error: #{response.code} - #{response.body}"
      Rails.logger.error error_message
      raise ApiError.new(error_message, response.code, response)
    end
  end

  def handle_success(response)
    parse_response(response)
  rescue JSON::ParserError, TypeError => e
    error_message = "Failed to parse HubSpot API response: #{e.message}"
    raise ApiError.new(error_message, response.code, response)
  end

  def parse_response(response)
    body = response.parsed_response

    if body.is_a?(Hash) && body['status'] == 'error'
      error_message = body['message'] || 'Unknown API error'
      raise ApiError.new(error_message, response.code, response)
    else
      body
    end
  end
end
