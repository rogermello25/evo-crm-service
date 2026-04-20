class Crm::Bms::ContactSyncJob < ApplicationJob
  queue_as :integrations

  def perform(contact_id, action = 'sync')
    @contact = Contact.find_by(id: contact_id)
    return unless @contact

    @hook = find_bms_hook
    return unless @hook&.feature_allowed?

    case action
    when 'sync'
      sync_contact
    when 'delete'
      # BMS doesn't support contact deletion via API
      # We could potentially add a tag to mark as deleted
      mark_contact_as_deleted
    else
      Rails.logger.warn("BMS Contact Sync Job: Unknown action '#{action}'")
    end
  rescue StandardError => e
    Rails.logger.error("BMS Contact Sync Job failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end

  private

  def sync_contact
    processor = Crm::Bms::ProcessorService.new(@hook)
    processor.handle_contact_updated(contact: @contact, saved_changes: {})
  end

  def mark_contact_as_deleted
    # Add a special tag to mark contact as deleted in BMS
    processor = Crm::Bms::ProcessorService.new(@hook)

    # Create a fake contact data with deletion tag
    contact_data = Crm::Bms::Mappers::ContactMapper.map(@contact)
    api_client = Crm::Bms::Api::ContactClient.new(@hook.settings['api_key'])
    api_client.add_tag_to_contact(contact_data, 'evolution-deleted')

    Rails.logger.info("BMS: Marked contact #{@contact.id} as deleted with tag")
  end

  def find_bms_hook
    Integrations::Hook.where(app_id: 'bms').first
  end
end
