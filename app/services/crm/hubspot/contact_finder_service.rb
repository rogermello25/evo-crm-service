class Crm::Hubspot::ContactFinderService
  def initialize(contact_client)
    @contact_client = contact_client
  end

  def find_or_create(contact)
    contact_id = get_stored_id(contact)
    return contact_id if contact_id.present?

    contact_id = find_by_contact(contact)
    return contact_id if contact_id.present?

    create_contact(contact)
  end

  private

  def find_by_contact(contact)
    contact_id = find_by_email(contact)
    contact_id = find_by_phone_number(contact) if contact_id.blank?

    contact_id
  end

  def find_by_email(contact)
    return if contact.email.blank?

    search_by_field(:email, contact.email)
  end

  def find_by_phone_number(contact)
    return if contact.phone_number.blank?

    contact_data = Crm::Hubspot::Mappers::ContactMapper.map(contact)
    return if contact_data.blank? || contact_data['phone'].nil?

    search_by_field(:phone, contact_data['phone'])
  end

  def search_by_field(field_type, value)
    contacts = case field_type
    when :email
      @contact_client.search_by_email(value)
    when :phone
      @contact_client.search_by_phone(value)
    end

    return nil unless contacts.is_a?(Array) && contacts.any?

    contacts.first['id']
  end

  def create_contact(contact)
    contact_data = Crm::Hubspot::Mappers::ContactMapper.map(contact)
    contact_id = @contact_client.create_contact(contact_data)

    raise StandardError, 'Failed to create contact - no ID returned' if contact_id.blank?

    contact_id
  end

  def get_stored_id(contact)
    return nil if contact.additional_attributes.blank?
    return nil if contact.additional_attributes['external'].blank?

    contact.additional_attributes.dig('external', 'hubspot_id')
  end
end
