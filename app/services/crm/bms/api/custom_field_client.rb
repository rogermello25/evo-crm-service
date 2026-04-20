class Crm::Bms::Api::CustomFieldClient < Crm::Bms::Api::BaseClient
  def initialize(api_key)
    super(api_key, 'https://bms-api.bri.us')
  end

  def create_custom_field(custom_field_data)
    response = make_request(:post, '/custom-fields', custom_field_data)

    # Extract custom field ID from response
    extract_custom_field_id(response)
  end

  def update_custom_field(custom_field_id, custom_field_data)
    # Include ID in the data payload as required by BMS API
    payload = custom_field_data.merge(id: custom_field_id)
    response = make_request(:put, "/custom-fields/#{custom_field_id}", payload)

    # Extract custom field ID from response
    extract_custom_field_id(response) || custom_field_id
  end

  def get_custom_field(custom_field_id)
    make_request(:get, "/custom-fields/#{custom_field_id}")
  end

  def list_custom_fields
    make_request(:get, '/custom-fields')
  end

  def delete_custom_field(custom_field_id)
    make_request(:delete, "/custom-fields/#{custom_field_id}")
  end

  def search_custom_field_by_title(title)
    # BMS might not have a specific search endpoint
    # We'll try to get all custom fields and filter by title

    custom_fields = list_custom_fields
    return nil unless custom_fields.is_a?(Array)

    custom_fields.find { |field| field['title'] == title }
  rescue ApiError => e
    Rails.logger.error("BMS: Error searching for custom field '#{title}': #{e.message}")
    nil
  end

  private

  def extract_custom_field_id(response)
    # Debug: log the exact response structure
    Rails.logger.info("BMS: Custom Field API Response body: #{response.inspect}")

    # Extract custom field ID from response
    if response.is_a?(Hash)
      custom_field_id = response['id'] || response['customFieldId'] || response['fieldId'] || response.dig('data', 'id')
      Rails.logger.info("BMS: Extracted custom field ID: #{custom_field_id}")

      # BMS API doesn't return custom field IDs, but successful creation is indicated by no error
      # Use placeholder ID or timestamp-based ID
      if custom_field_id.blank?
        custom_field_id = "bms-field-#{Time.current.to_i}-#{SecureRandom.hex(4)}"
        Rails.logger.info("BMS: Generated fallback custom field ID: #{custom_field_id}")
      end

      custom_field_id
    else
      Rails.logger.info("BMS: Response is not a hash: #{response.class}")
      response
    end
  end
end
