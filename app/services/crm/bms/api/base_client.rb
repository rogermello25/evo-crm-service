require 'net/http'
require 'json'

class Crm::Bms::Api::BaseClient
  API_BASE_URL = 'https://bms-api.bri.us'.freeze

  class ApiError < StandardError
    attr_reader :response, :status_code

    def initialize(message, response = nil)
      super(message)
      @response = response
      @status_code = response&.code&.to_i
    end
  end

  def initialize(api_key, custom_base_url = nil)
    @api_key = api_key
    @base_url = custom_base_url || API_BASE_URL
    validate_api_key!
  end

  protected

  attr_reader :api_key

  def make_request(method, endpoint, payload = nil)
    uri = URI("#{@base_url}#{endpoint}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30
    http.open_timeout = 30

    request = build_request(method, uri, payload)
    set_headers(request)

    Rails.logger.info("BMS API: #{method.upcase} #{uri}")
    Rails.logger.debug { "BMS API Payload: #{payload.to_json}" } if payload

    response = http.request(request)
    handle_response(response)
  rescue Timeout::Error => e
    raise ApiError, "BMS API timeout: #{e.message}"
  rescue StandardError => e
    raise ApiError, "BMS API error: #{e.message}"
  end

  private

  def validate_api_key!
    raise ArgumentError, 'API Key is required' if api_key.blank?
  end

  def build_request(method, uri, payload)
    case method.to_s.downcase
    when 'get'
      Net::HTTP::Get.new(uri)
    when 'post'
      request = Net::HTTP::Post.new(uri)
      request.body = payload.to_json if payload
      request
    when 'put'
      request = Net::HTTP::Put.new(uri)
      request.body = payload.to_json if payload
      request
    when 'delete'
      Net::HTTP::Delete.new(uri)
    else
      raise ArgumentError, "Unsupported HTTP method: #{method}"
    end
  end

  def set_headers(request)
    request['Content-Type'] = 'application/json'
    request['api-key'] = api_key
    request['User-Agent'] = 'Evolution-BMS-Integration/1.0'
  end

  def handle_response(response)
    Rails.logger.info("BMS API Response: #{response.code}")
    Rails.logger.debug { "BMS API Response Body: #{response.body}" }

    case response.code.to_i
    when 200..299
      parse_response_body(response)
    when 400
      raise ApiError.new("Bad Request: #{parse_error_message(response)}", response)
    when 401
      raise ApiError.new('Unauthorized: Invalid API key', response)
    when 403
      raise ApiError.new('Forbidden: Access denied', response)
    when 404
      raise ApiError.new('Not Found: Resource not found', response)
    when 429
      raise ApiError.new('Rate Limited: Too many requests', response)
    when 500..599
      raise ApiError.new("Server Error: #{parse_error_message(response)}", response)
    else
      raise ApiError.new("Unexpected response: #{response.code}", response)
    end
  end

  def parse_response_body(response)
    return {} if response.body.blank?

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    Rails.logger.error("BMS API: Failed to parse response body: #{e.message}")
    { 'raw_body' => response.body }
  end

  def parse_error_message(response)
    return response.message if response.body.blank?

    parsed = JSON.parse(response.body)
    parsed['message'] || parsed['error'] || response.message
  rescue JSON::ParserError
    response.body
  end
end
