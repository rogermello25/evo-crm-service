class Crm::Hubspot::ProcessorService < Crm::BaseProcessorService
  def self.crm_name
    'hubspot'
  end

  def initialize(hook)
    super(hook)
    @hook = hook

    # For now, we'll focus on contact sync only (Fase 2)
    # Activity sync will be implemented in later phases

    # Initialize API clients
    @contact_client = Crm::Hubspot::Api::ContactClient.new(@hook)
    @contact_finder = Crm::Hubspot::ContactFinderService.new(@contact_client)
  end

  def handle_contact_created(event_data)
    handle_contact(event_data[:contact])
  end

  def handle_contact_updated(event_data)
    handle_contact(event_data[:contact])
  end

  def handle_conversation_created(event_data)
    # For Fase 2, we only sync contacts
    # Activities will be implemented in later phases
    Rails.logger.info("HubSpot: Conversation activities not implemented yet (Fase 3)")
  end

  def handle_conversation_resolved(event_data)
    # For Fase 2, we only sync contacts
    # Activities will be implemented in later phases
    Rails.logger.info("HubSpot: Conversation activities not implemented yet (Fase 3)")
  end

  def handle_contact(contact)
    contact.reload
    unless identifiable_contact?(contact)
      Rails.logger.info("Contact not identifiable. Skipping handle_contact for ##{contact.id}")
      return
    end

    stored_contact_id = get_external_id(contact)
    create_or_update_contact(contact, stored_contact_id)
  end

  private

  def create_or_update_contact(contact, contact_id)
    contact_data = Crm::Hubspot::Mappers::ContactMapper.map(contact)

    if contact_id.present?
      @contact_client.update_contact(contact_id, contact_data)
      Rails.logger.info("Updated HubSpot contact #{contact_id} for Evolution contact #{contact.id}")
    else
      new_contact_id = @contact_finder.find_or_create(contact)
      store_external_id(contact, new_contact_id)
      Rails.logger.info("Created/Found HubSpot contact #{new_contact_id} for Evolution contact #{contact.id}")
    end
  rescue Crm::Hubspot::Api::BaseClient::ApiError => e
    EvolutionExceptionTracker.new(e).capture_exception
    Rails.logger.error "HubSpot API error processing contact: #{e.message}"
  rescue StandardError => e
    EvolutionExceptionTracker.new(e).capture_exception
    Rails.logger.error "Error processing contact in HubSpot: #{e.message}"
  end
end
