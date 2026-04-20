class Crm::Bms::Api::ContactClient < Crm::Bms::Api::BaseClient
  def initialize(api_key)
    super(api_key, 'https://in.bri.us')
  end

  def create_contact(contact_data)
    payload = build_contact_payload(contact_data, tag_name: '')
    response = make_request(:post, '/bms/leads', payload)

    # BMS API should return the created contact ID or the contact object
    extract_contact_id(response)
  end

  def update_contact(contact_data)
    payload = build_contact_payload(contact_data, tag_name: '')
    response = make_request(:post, '/bms/leads', payload)

    # BMS API should return the updated contact ID or the contact object
    extract_contact_id(response)
  end

  def search_by_email(email)
    # BMS doesn't have a specific search endpoint documented
    # We'll implement a simple approach by trying to create/update
    # which will return existing contact if found
    search_contact_by_field(email: email)
  end

  def search_by_phone(phone)
    search_contact_by_field(phone: phone)
  end

  def add_tag_to_contact(contact_data, tag_name)
    payload = build_contact_payload(contact_data, tag_name: tag_name)
    make_request(:post, '/bms/leads', payload)
  end

  def remove_tag_from_contact(contact_data, tag_name)
    payload = build_contact_payload(contact_data, remove_tag: tag_name)
    make_request(:post, '/bms/leads', payload)
  end

  private

  # Method to make requests to the old BMS API URL for updates
  def make_request_to_old_api(method, endpoint, payload = nil)
    old_base_url = 'https://bms-api.bri.us'
    uri = URI("#{old_base_url}#{endpoint}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30
    http.open_timeout = 30

    # Build headers
    headers = {
      'Content-Type' => 'application/json',
      'api-key' => api_key
    }

    # Create request
    case method
    when :post
      request = Net::HTTP::Post.new(uri.path, headers)
      request.body = payload.to_json if payload
    when :get
      request = Net::HTTP::Get.new(uri.path, headers)
    when :put
      request = Net::HTTP::Put.new(uri.path, headers)
      request.body = payload.to_json if payload
    when :delete
      request = Net::HTTP::Delete.new(uri.path, headers)
    else
      raise ArgumentError, "Unsupported HTTP method: #{method}"
    end

    Rails.logger.info("BMS API: #{method.upcase} #{uri}")

    begin
      response = http.request(request)
      Rails.logger.info("BMS API Response: #{response.code}")

      handle_response(response)
    rescue Timeout::Error => e
      raise Crm::Bms::Api::BaseClient::ApiError, "BMS API timeout: #{e.message}"
    rescue StandardError => e
      Rails.logger.error("BMS API request failed: #{e.message}")
      raise Crm::Bms::Api::BaseClient::ApiError, "BMS API request failed: #{e.message}"
    end
  end

  # Handle API response (copied from BaseClient)
  def handle_response(response)
    case response.code.to_i
    when 200..299
      # Success response
      if response.body.present?
        JSON.parse(response.body)
      else
        { success: true }
      end
    when 400
      error_message = parse_error_message(response) || 'Bad Request'
      raise Crm::Bms::Api::BaseClient::ApiError.new("Client Error: #{error_message}", response)
    when 401
      raise Crm::Bms::Api::BaseClient::ApiError.new('Unauthorized: Check your API key', response)
    when 403
      raise Crm::Bms::Api::BaseClient::ApiError.new('Forbidden: Insufficient permissions', response)
    when 404
      raise Crm::Bms::Api::BaseClient::ApiError.new('Not Found: The requested resource does not exist', response)
    when 429
      raise Crm::Bms::Api::BaseClient::ApiError.new('Rate Limited: Too many requests', response)
    when 500..599
      error_message = parse_error_message(response) || 'Internal Server Error'
      raise Crm::Bms::Api::BaseClient::ApiError.new("Server Error: #{error_message}", response)
    else
      raise Crm::Bms::Api::BaseClient::ApiError.new("Unexpected response code: #{response.code}", response)
    end
  end

  # Parse error message from response (copied from BaseClient)
  def parse_error_message(response)
    return nil unless response.body

    parsed_body = JSON.parse(response.body)
    parsed_body['message'] || parsed_body['error'] || parsed_body['errors']&.first
  rescue JSON::ParserError
    nil
  end

  def build_contact_payload(contact_data, options = {})
    Rails.logger.info("BMS: build_contact_payload called with options: #{options.inspect}")

    payload = {
      contact: contact_data[:contact],
      tagName: options[:tag_name] || '',  # Always include tagName, even if empty
      apiKey: api_key  # Must include apiKey in payload as per documentation
    }

    # Add remove tag if specified
    payload[:removeTag] = options[:remove_tag] if options[:remove_tag].present?

    Rails.logger.info("BMS: Final payload built: #{payload.to_json}")
    payload
  end

  def search_contact_by_field(search_criteria)
    # Create a minimal contact object for search
    contact_data = {
      contact: search_criteria
    }

    # Try to create/update which will return existing contact if found
    begin
      response = create_contact(contact_data)
      # If successful, extract contact information
      [extract_contact_info(response)]
    rescue ApiError => e
      # If contact already exists, BMS might return an error with contact info
      # This depends on BMS API behavior - might need adjustment based on actual API
      Rails.logger.info("BMS: Contact search resulted in: #{e.message}")
      []
    end
  end

  def extract_contact_id(response)
    # Debug: log the exact response structure
    Rails.logger.info("BMS: API Response body: #{response.inspect}")

    # Extract contact ID from response
    # The structure depends on actual BMS API response format
    if response.is_a?(Hash)
      contact_id = response['id'] || response['contactId'] || response.dig('contact', 'id') || response.dig('data', 'id')
      Rails.logger.info("BMS: Extracted contact ID: #{contact_id}")

      # If no ID found but response is successful, generate a placeholder ID
      if contact_id.nil? && response['success'] != false
        placeholder_id = "bms-#{Time.current.to_i}-#{SecureRandom.hex(4)}"
        Rails.logger.info("BMS: No ID returned, using placeholder: #{placeholder_id}")
        return placeholder_id
      end

      contact_id
    else
      Rails.logger.info("BMS: Response is not a hash: #{response.class}")
      # If response is not a hash but request was successful, generate placeholder ID
      placeholder_id = "bms-#{Time.current.to_i}-#{SecureRandom.hex(4)}"
      Rails.logger.info("BMS: Non-hash response, using placeholder: #{placeholder_id}")
      placeholder_id
    end
  end

  def extract_contact_info(response)
    # Extract contact information for search results
    if response.is_a?(Hash)
      {
        'id' => extract_contact_id(response),
        'email' => response.dig('contact', 'email') || response['email'],
        'phone' => response.dig('contact', 'phone') || response['phone']
      }
    else
      { 'id' => response }
    end
  end
end
