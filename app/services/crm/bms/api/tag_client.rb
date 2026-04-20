class Crm::Bms::Api::TagClient < Crm::Bms::Api::BaseClient
  def initialize(api_key)
    super(api_key, 'https://bms-api.bri.us')
  end

  def create_tag(tag_data)
    response = make_request(:post, '/tags', tag_data)

    # Extract tag ID from response
    extract_tag_id(response)
  end

  def update_tag(tag_id, tag_data)
    response = make_request(:put, "/tags/#{tag_id}", tag_data)

    # Extract tag ID from response
    extract_tag_id(response) || tag_id
  end

  def get_tag(tag_id)
    make_request(:get, "/tags/#{tag_id}")
  end

  def list_tags
    make_request(:get, '/tags')
  end

  def delete_tag(tag_id)
    make_request(:delete, "/tags/#{tag_id}")
  end

  def search_tag_by_name(name)
    # BMS might not have a specific search endpoint
    # We'll try to get all tags and filter by name

    tags = list_tags
    return nil unless tags.is_a?(Array)

    tags.find { |tag| tag['name'] == name }
  rescue ApiError => e
    Rails.logger.error("BMS: Error searching for tag '#{name}': #{e.message}")
    nil
  end

  private

  def extract_tag_id(response)
    if response.is_a?(Hash)
      response['id'] || response['tagId']
    else
      response
    end
  end
end
