class Crm::Hubspot::Api::ContactClient < Crm::Hubspot::Api::BaseClient
  # Search contacts by email
  # https://developers.hubspot.com/docs/api/crm/search
  def search_by_email(email)
    raise ArgumentError, 'Email is required' if email.blank?

    path = '/crm/v3/objects/contacts/search'
    body = {
      filterGroups: [
        {
          filters: [
            {
              propertyName: 'email',
              operator: 'EQ',
              value: email
            }
          ]
        }
      ],
      properties: ['id', 'email', 'firstname', 'lastname', 'phone', 'createdate']
    }

    response = post(path, {}, body)
    response['results']
  end

  # Search contacts by phone
  def search_by_phone(phone)
    raise ArgumentError, 'Phone is required' if phone.blank?

    path = '/crm/v3/objects/contacts/search'
    body = {
      filterGroups: [
        {
          filters: [
            {
              propertyName: 'phone',
              operator: 'EQ',
              value: phone
            }
          ]
        }
      ],
      properties: ['id', 'email', 'firstname', 'lastname', 'phone', 'createdate']
    }

    response = post(path, {}, body)
    response['results']
  end

  # Get contact by ID
  # https://developers.hubspot.com/docs/api/crm/contacts
  def get_contact(contact_id)
    raise ArgumentError, 'Contact ID is required' if contact_id.blank?

    path = "/crm/v3/objects/contacts/#{contact_id}"
    params = {
      properties: 'email,firstname,lastname,phone,createdate,lastmodifieddate'
    }

    get(path, params)
  end

  # Create new contact
  # https://developers.hubspot.com/docs/api/crm/contacts
  def create_contact(contact_data)
    raise ArgumentError, 'Contact data is required' if contact_data.blank?

    path = '/crm/v3/objects/contacts'
    body = {
      properties: contact_data
    }

    response = post(path, {}, body)
    response['id']
  end

  # Update existing contact
  # https://developers.hubspot.com/docs/api/crm/contacts
  def update_contact(contact_id, contact_data)
    raise ArgumentError, 'Contact ID is required' if contact_id.blank?
    raise ArgumentError, 'Contact data is required' if contact_data.blank?

    path = "/crm/v3/objects/contacts/#{contact_id}"
    body = {
      properties: contact_data
    }

    response = patch(path, {}, body)
    response['id']
  end

  # Batch search contacts (for efficient bulk operations)
  def batch_search(filters)
    path = '/crm/v3/objects/contacts/search'
    body = {
      filterGroups: filters,
      properties: ['id', 'email', 'firstname', 'lastname', 'phone', 'createdate'],
      limit: 100
    }

    response = post(path, {}, body)
    response['results']
  end
end
