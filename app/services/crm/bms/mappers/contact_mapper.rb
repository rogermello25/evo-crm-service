class Crm::Bms::Mappers::ContactMapper
  def self.map(contact)
    new(contact).map
  end

  def initialize(contact)
    @contact = contact
  end

  def map
    contact_attrs = build_contact_attributes
    Rails.logger.info("BMS: Mapped contact attributes: #{contact_attrs.to_json}")

    {
      contact: contact_attrs
    }
  end

  private

  attr_reader :contact

  def build_contact_attributes
    base_attributes = {}

    # Only add fields that have values
    base_attributes[:email] = contact.email if contact.email.present?
    base_attributes[:firstName] = extract_first_name if extract_first_name.present?
    base_attributes[:lastName] = extract_last_name if extract_last_name.present?
    base_attributes[:phone] = formatted_phone_number if formatted_phone_number.present?

    # Add location data if available
    base_attributes[:city] = contact.location if contact.location.present?
    base_attributes[:region] = extract_region if extract_region.present?

    # Add custom fields from custom_attributes
    base_attributes[:customFields] = map_custom_attributes if contact.custom_attributes.present?

    # Always add devices information (required by BMS API)
    base_attributes[:devices] = map_device_information

    base_attributes.compact
  end

  def extract_first_name
    return contact.name if contact.last_name.blank?

    # If we have both name and last_name, name is the first name
    contact.name.presence
  end

  def extract_last_name
    contact.last_name.presence
  end

  def extract_region
    # Try to get region from additional_attributes or country_code
    contact.additional_attributes&.dig('region') ||
      contact.additional_attributes&.dig('state') ||
      contact.country_code&.upcase
  end

  def formatted_phone_number
    return nil if contact.phone_number.blank?

    # BMS expects phone with + prefix
    phone = contact.phone_number.strip
    phone = "+#{phone}" unless phone.start_with?('+')

    phone
  end

  def map_custom_attributes
    custom_fields = {}

    # Map Evolution custom attributes to BMS custom fields
    contact.custom_attributes.each do |key, value|
      # Convert Evolution attribute keys to BMS custom field format
      bms_key = map_attribute_key(key)
      custom_fields[bms_key] = format_attribute_value(value)
    end

    # Add additional attributes that might be useful for BMS
    add_additional_custom_fields(custom_fields)

    custom_fields.compact
  end

  def map_attribute_key(evolution_key)
    # Map common Evolution attribute keys to BMS custom field keys
    key_mapping = {
      'cpf' => 'cpf',
      'gender' => 'gender',
      'birth_date' => 'birth-date',
      'income' => 'income',
      'education' => 'education',
      'occupation' => 'occupation',
      'company' => 'company',
      'industry' => 'industry'
    }

    key_mapping[evolution_key] || evolution_key
  end

  def format_attribute_value(value)
    case value
    when Date, DateTime, Time
      value.strftime('%Y/%m/%d')
    when TrueClass, FalseClass
      value.to_s
    else
      value.to_s
    end
  end

  def add_additional_custom_fields(custom_fields)
    # Add user agent if available
    if contact.additional_attributes&.dig('browser')
      user_agent = build_user_agent_string
      custom_fields['user_agent'] = user_agent if user_agent.present?
    end

    # Add social profiles information
    if contact.additional_attributes&.dig('social_profiles').present?
      social_info = extract_social_info
      custom_fields.merge!(social_info) if social_info.any?
    end

    # Add conversation source information
    return if contact.additional_attributes&.dig('referer').blank?

    custom_fields['referer'] = contact.additional_attributes['referer']
  end

  def build_user_agent_string
    browser_info = contact.additional_attributes['browser']
    return nil unless browser_info.is_a?(Hash)

    browser_name = browser_info['browser_name'] || 'Unknown'
    browser_version = browser_info['browser_version'] || '1.0'
    platform = browser_info['platform'] || 'Unknown'

    "#{browser_name}/#{browser_version} (#{platform})"
  end

  def extract_social_info
    social_fields = {}
    social_profiles = contact.additional_attributes['social_profiles']

    return social_fields unless social_profiles.is_a?(Hash)

    # Map social profile information to custom fields
    social_profiles.each do |platform, profile_data|
      next unless profile_data.is_a?(Hash)

      case platform
      when 'facebook'
        social_fields['facebook_profile'] = profile_data['link'] if profile_data['link']
        social_fields['facebook_id'] = profile_data['id'] if profile_data['id']
      when 'instagram'
        social_fields['instagram_profile'] = profile_data['link'] if profile_data['link']
        social_fields['instagram_id'] = profile_data['id'] if profile_data['id']
      when 'twitter'
        social_fields['twitter_profile'] = profile_data['link'] if profile_data['link']
        social_fields['twitter_handle'] = profile_data['screen_name'] if profile_data['screen_name']
      when 'linkedin'
        social_fields['linkedin_profile'] = profile_data['link'] if profile_data['link']
      end
    end

    social_fields
  end

  def should_include_device_info?
    # Include device info if we have browser information or if contact came from web widget
    contact.additional_attributes&.dig('browser').present? ||
      contact.additional_attributes&.dig('initiated_at').present?
  end

  def map_device_information
    devices = []

    # Always create at least one device entry for BMS API compatibility
    device_info = build_device_info
    devices << device_info if device_info

    devices
  end

  def build_device_info
    # Try to get browser info from additional_attributes, use defaults if not available
    browser_info = contact.additional_attributes&.dig('browser') || {}

    # Determine device type based on available information
    device_type = determine_device_type

    {
      contactId: contact.id,
      type: device_type,
      token: generate_device_token,
      browser: extract_browser_name(browser_info),
      os: extract_operating_system(browser_info)
    }
  end

  def build_web_device_info
    # Keep old method for backward compatibility
    build_device_info
  end

  def generate_device_token
    # Generate a unique token for this contact/device combination
    # This could be used for web push notifications in the future
    "evolution-#{contact.id}-#{SecureRandom.hex(8)}"
  end

  def determine_device_type
    # Check contact inboxes to determine the primary channel type
    primary_inbox = contact.contact_inboxes.first&.inbox

    case primary_inbox&.channel_type
    when 'Channel::WhatsApp'
      'whatsapp'
    when 'Channel::Telegram'
      'telegram'
    when 'Channel::WebWidget'
      'web-widget'
    when 'Channel::Email'
      'email'
    else
      'none' # Default fallback
    end
  end

  def extract_browser_name(browser_info)
    return 'Evolution CRM' unless browser_info.is_a?(Hash)

    browser_info['browser_name'] ||
      browser_info['name'] ||
      'Evolution CRM'
  end

  def extract_operating_system(browser_info)
    return 'Unknown' unless browser_info.is_a?(Hash)

    browser_info['platform'] ||
      browser_info['os'] ||
      browser_info['operating_system'] ||
      'Unknown'
  end
end
