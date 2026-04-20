class Crm::Hubspot::Api::DealClient < Crm::Hubspot::Api::BaseClient
  # Search deals by term
  # https://developers.hubspot.com/docs/api/crm/search
  def search_deals(search_term = '')
    Rails.logger.info "DealClient: search_deals called with term: '#{search_term}'"

    if search_term.blank? || search_term == '*'
      # Get recent deals when no search term provided
      path = '/crm/v3/objects/deals'
      params = {
        properties: 'id,dealname,amount,dealstage,pipeline,closedate,hubspot_owner_id,createdate',
        limit: 50,
        sort: 'createdate'
      }
      Rails.logger.info "DealClient: Getting recent deals from #{path} with params: #{params}"
      response = get(path, params)
      Rails.logger.info "DealClient: Response received: #{response.class} - #{response&.keys if response.is_a?(Hash)}"

      if response && response['results']
        Rails.logger.info "DealClient: Found #{response['results'].length} deals"
        response['results']
      else
        Rails.logger.error "DealClient: No results in response: #{response}"
        []
      end
    else
      # Search deals by name
      path = '/crm/v3/objects/deals/search'
      body = {
        filterGroups: [
          {
            filters: [
              {
                propertyName: 'dealname',
                operator: 'CONTAINS_TOKEN',
                value: search_term
              }
            ]
          }
        ],
        properties: ['id', 'dealname', 'amount', 'dealstage', 'pipeline', 'closedate', 'hubspot_owner_id', 'createdate'],
        limit: 100
      }

      Rails.logger.info "DealClient: Searching deals with body: #{body}"
      response = post(path, {}, body)
      Rails.logger.info "DealClient: Search response: #{response.class} - #{response&.keys if response.is_a?(Hash)}"

      if response && response['results']
        Rails.logger.info "DealClient: Found #{response['results'].length} search results"
        response['results']
      else
        Rails.logger.error "DealClient: No results in search response: #{response}"
        []
      end
    end
  rescue => e
    Rails.logger.error "DealClient: Exception in search_deals: #{e.message}"
    Rails.logger.error "DealClient: Backtrace: #{e.backtrace.first(5)}"
    raise
  end

  # Get deal by ID
  # https://developers.hubspot.com/docs/api/crm/deals
  def get_deal(deal_id)
    raise ArgumentError, 'Deal ID is required' if deal_id.blank?

    path = "/crm/v3/objects/deals/#{deal_id}"
    params = {
      properties: 'dealname,amount,dealstage,pipeline,closedate,hubspot_owner_id,createdate,hs_deal_stage_probability'
    }

    get(path, params)
  end

  # Create new deal
  # https://developers.hubspot.com/docs/api/crm/deals
  def create_deal(deal_data)
    raise ArgumentError, 'Deal data is required' if deal_data.blank?

    path = '/crm/v3/objects/deals'
    body = {
      properties: deal_data
    }

    Rails.logger.info "DealClient: Calling POST #{path} with body: #{body}"
    response = post(path, {}, body)
    Rails.logger.info "DealClient: Response received: #{response}"
    Rails.logger.info "DealClient: Response class: #{response.class}"

    response['id']
  rescue => e
    Rails.logger.error "DealClient: Error in create_deal: #{e.message}"
    Rails.logger.error "DealClient: Backtrace: #{e.backtrace.first(5)}"
    raise
  end

  # Update existing deal
  # https://developers.hubspot.com/docs/api/crm/deals
  def update_deal(deal_id, deal_data)
    raise ArgumentError, 'Deal ID is required' if deal_id.blank?
    raise ArgumentError, 'Deal data is required' if deal_data.blank?

    path = "/crm/v3/objects/deals/#{deal_id}"
    body = {
      properties: deal_data
    }

    response = patch(path, {}, body)
    response['id']
  end

  # Get pipelines
  # https://developers.hubspot.com/docs/api/crm/pipelines
  def get_pipelines
    path = '/crm/v3/pipelines/deals'
    get(path)
  end

  # Get pipeline stages
  # https://developers.hubspot.com/docs/api/crm/pipelines
  def get_pipeline_stages(pipeline_id)
    raise ArgumentError, 'Pipeline ID is required' if pipeline_id.blank?

    path = "/crm/v3/pipelines/deals/#{pipeline_id}"
    get(path)
  end

  # Get owners
  # https://developers.hubspot.com/docs/api/crm/owners
  def get_owners
    path = '/crm/v3/owners'
    get(path)
  end
end
