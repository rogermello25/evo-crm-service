# Service Object para transferir múltiplos contatos de uma empresa para outra
class Contacts::BulkTransferService
  include Wisper::Publisher

  def initialize(contact_ids:, from_company_id:, to_company_id:, account: nil)
    @contact_ids = contact_ids
    @from_company_id = from_company_id
    @to_company_id = to_company_id
    @transferred_count = 0
  end

  def perform
    validate_params!

    ActiveRecord::Base.transaction do
      transfer_contacts
      publish_events
    end

    success_response
  rescue StandardError => e
    error_response(e.message)
  end

  private

  attr_reader :contact_ids, :from_company_id, :to_company_id, :transferred_count

  def validate_params!
    raise 'From company not found' unless from_company
    raise 'To company not found' unless to_company
    raise 'From must be a company' unless from_company.company?
    raise 'To must be a company' unless to_company.company?
  end

  def from_company
    @from_company ||= Contact.find_by(id: from_company_id, type: 'company')
  end

  def to_company
    @to_company ||= Contact.find_by(id: to_company_id, type: 'company')
  end

  def contacts
    @contacts ||= Contact.where(id: contact_ids, type: 'person')
  end

  def transfer_contacts
    contacts.each do |contact|
      contact.remove_company(from_company) if contact.companies.include?(from_company)

      @transferred_count += 1 if contact.add_company(to_company)
    end
  end

  def publish_events
    publish(:contacts_bulk_transferred, data: {
      contacts: contacts,
      from_company: from_company,
      to_company: to_company
    })
  end

  def success_response
    {
      success: true,
      transferred_count: transferred_count,
      from_company: from_company,
      to_company: to_company
    }
  end

  def error_response(message)
    { success: false, error: message }
  end
end

