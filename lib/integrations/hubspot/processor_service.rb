class Integrations::Hubspot::ProcessorService

  def pipelines
    response = hubspot_client.get_pipelines
    return { error: response[:error] } if response[:error]

    { data: response['results'].map(&:as_json) }
  rescue => e
    { error: e.message }
  end

  def pipeline_stages(pipeline_id)
    response = hubspot_client.get_pipeline_stages(pipeline_id)
    return { error: response[:error] } if response[:error]

    { data: response['stages'].map(&:as_json) }
  rescue => e
    { error: e.message }
  end

  def owners
    response = hubspot_client.get_owners
    return { error: response[:error] } if response[:error]

    { data: response['results'].map(&:as_json) }
  rescue => e
    { error: e.message }
  end

  def create_deal(params)
    deal_data = {
      'dealname' => params[:title],
      'amount' => params[:amount],
      'dealstage' => params[:stage_id],
      'pipeline' => params[:pipeline_id],
      'hubspot_owner_id' => params[:owner_id],
      'closedate' => params[:close_date]
    }.compact

    Rails.logger.info "Creating HubSpot deal with data: #{deal_data}"

    response = hubspot_client.create_deal(deal_data)
    Rails.logger.info "HubSpot create_deal response: #{response}"

    return { error: response[:error] } if response.is_a?(Hash) && response[:error]

    { data: { id: response, title: params[:title] } }
  rescue => e
    Rails.logger.error "HubSpot create_deal error: #{e.message}"
    Rails.logger.error "HubSpot create_deal backtrace: #{e.backtrace.first(10)}"
    { error: e.message }
  end

  def link_deal(link, deal_id, title)
    # HubSpot doesn't have direct linking like Linear, so we'll store metadata in conversation
    begin
      conversation = find_conversation_from_link(link)
      return { error: 'Conversation not found' } unless conversation

      # Store the deal association in conversation metadata
      metadata = conversation.additional_attributes || {}
      metadata['hubspot'] = {} unless metadata['hubspot']
      metadata['hubspot']['linked_deal_id'] = deal_id
      metadata['hubspot']['linked_deal_title'] = title

      conversation.update!(additional_attributes: metadata)

      { data: { id: deal_id, link: link, link_id: "#{conversation.id}_#{deal_id}" } }
    rescue => e
      { error: e.message }
    end
  end

  def unlink_deal(link_id)
    # Extract conversation ID from link_id
    begin
      conversation_id, deal_id = link_id.split('_')
      conversation = Conversation.find(conversation_id)

      metadata = conversation.additional_attributes || {}
      metadata['hubspot']&.delete('linked_deal_id')
      metadata['hubspot']&.delete('linked_deal_title')

      conversation.update!(additional_attributes: metadata)

      { data: { link_id: link_id } }
    rescue => e
      { error: e.message }
    end
  end

  def search_deals(term)
    Rails.logger.info "ProcessorService: Searching deals with term: '#{term}'"
    response = hubspot_client.search_deals(term)
    Rails.logger.info "ProcessorService: Response class: #{response.class}"
    Rails.logger.info "ProcessorService: Response: #{response.inspect}"

    # Check if response is a Hash with error
    if response.is_a?(Hash) && response[:error]
      Rails.logger.error "ProcessorService: Error in response: #{response[:error]}"
      return { error: response[:error] }
    end

    # Response should be an array of deals
    if response.is_a?(Array)
      { data: response.map(&:as_json) }
    else
      Rails.logger.error "ProcessorService: Unexpected response type: #{response.class}"
      { error: "Unexpected response format" }
    end
  rescue => e
    Rails.logger.error "ProcessorService: Exception in search_deals: #{e.message}"
    Rails.logger.error "ProcessorService: Backtrace: #{e.backtrace.first(5)}"
    { error: e.message }
  end

  def linked_deals(url)
    begin
      conversation = find_conversation_from_link(url)
      return { data: [] } unless conversation

      linked_deal_id = conversation.additional_attributes&.dig('hubspot', 'linked_deal_id')
      return { data: [] } unless linked_deal_id

      # Get deal details from HubSpot
      deal = hubspot_client.get_deal(linked_deal_id)
      return { error: deal[:error] } if deal[:error]

      # Format like Linear attachment
      deal_data = {
        'id' => "#{conversation.id}_#{linked_deal_id}",
        'deal' => deal
      }

      { data: [deal_data] }
    rescue => e
      { error: e.message }
    end
  end

  private

  def hubspot_hook
    @hubspot_hook ||= Hook.find_by!(app_id: 'hubspot')
  end

  def hubspot_client
    @hubspot_client ||= Crm::Hubspot::Api::DealClient.new(hubspot_hook)
  end

  def find_conversation_from_link(link)
    # Extract conversation display_id from URL
    # URL format: /app/conversations/{display_id}
    match = link.match(/conversations\/(\d+)/)
    return nil unless match

    display_id = match[1]
    Conversation.find_by(display_id: display_id)
  end
end
