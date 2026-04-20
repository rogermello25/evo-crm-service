class Crm::Hubspot::Mappers::ContactMapper
  def self.map(contact)
    new(contact).map
  end

  def initialize(contact)
    @contact = contact
  end

  def map
    base_attributes
  end

  private

  attr_reader :contact

  def base_attributes
    {
      'firstname' => contact.name.presence,
      'lastname' => contact.last_name.presence,
      'email' => contact.email.presence,
      'phone' => formatted_phone_number,
      'hs_lead_status' => 'NEW',
      'lifecyclestage' => 'lead'
      # Note: Custom properties like 'evolution_contact_id' and 'evolution_source'
      # need to be created in HubSpot first. Will be implemented in future phase.
    }.compact
  end

  def formatted_phone_number
    # HubSpot accepts various phone number formats
    # We'll use E.164 format for consistency
    return nil if contact.phone_number.blank?

    parsed = TelephoneNumber.parse(contact.phone_number)
    return contact.phone_number unless parsed.valid?

    parsed.e164_number
  end

  def brand_name
    ::GlobalConfig.get('BRAND_NAME')['BRAND_NAME'] || 'Evolution'
  end

  def brand_name_without_spaces
    brand_name.gsub(/\s+/, '')
  end
end
