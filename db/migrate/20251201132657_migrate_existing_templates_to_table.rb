class MigrateExistingTemplatesToTable < ActiveRecord::Migration[7.1]
  def up
    migrate_whatsapp_templates
    migrate_instagram_templates
    migrate_facebook_templates
    migrate_telegram_templates
    migrate_twilio_sms_templates
    migrate_line_templates
  end

  def down
    MessageTemplate.delete_all
  end

  private

  def migrate_whatsapp_templates
    
    Channel::Whatsapp.find_each do |channel|
      templates_data = channel.read_attribute(:message_templates)
      next if templates_data.blank?

      templates_array = templates_data.is_a?(Hash) ? templates_data.values : [templates_data]
      
      templates_array.each do |template|
        next if template.blank?
        next unless template.is_a?(Hash)
        next if template['name'].blank?

        create_message_template(
          channel: channel,
          template: template,
          last_updated: channel.message_templates_last_updated
        )
      rescue StandardError => e
        template_name = template.is_a?(Hash) ? template['name'] : 'unknown'
      end
    end
  end

  # Instagram, Facebook, Telegram, TwilioSms, Line used Array (default: [])
  def migrate_instagram_templates
    migrate_array_templates('Instagram', Channel::Instagram)
  end

  def migrate_facebook_templates
    migrate_array_templates('Facebook', Channel::FacebookPage)
  end

  def migrate_telegram_templates
    migrate_array_templates('Telegram', Channel::Telegram)
  end

  def migrate_twilio_sms_templates
    migrate_array_templates('TwilioSms', Channel::TwilioSms)
  end

  def migrate_line_templates
    migrate_array_templates('Line', Channel::Line)
  end

  def migrate_array_templates(channel_name, channel_class)
    channel_class.find_each do |channel|
      templates_data = channel.read_attribute(:message_templates)
      next if templates_data.blank?

      templates_array = templates_data.is_a?(Array) ? templates_data : [templates_data]
      
      templates_array.each do |template|
        next if template.blank?
        next unless template.is_a?(Hash)
        next if template['name'].blank?

        create_message_template(
          channel: channel,
          template: template,
          last_updated: channel.message_templates_last_updated
        )
      rescue StandardError => e
        template_name = template.is_a?(Hash) ? template['name'] : 'unknown'
      end
    end
  end

  def create_message_template(channel:, template:, last_updated:)
    content = extract_content_from_template(template)
    
    MessageTemplate.create!(
      channel: channel,
      name: template['name'],
      content: content,
      language: template['language'] || 'pt_BR',
      category: template['category'],
      template_type: determine_template_type(template),
      components: extract_components(template),
      variables: extract_variables(template),
      media_url: template['media_url'],
      media_type: template['media_type'],
      settings: extract_settings(template),
      metadata: extract_metadata(template),
      active: template['status'] == 'APPROVED' || template['status'].nil?,
      created_at: last_updated || Time.current,
      updated_at: last_updated || Time.current
    )
  end

  def extract_content_from_template(template)
    if template['components']&.is_a?(Array)
      body_component = template['components'].find { |c| c['type'] == 'BODY' }
      return body_component['text'] if body_component&.dig('text')
    end
    
    # Fallback para outros campos
    template['text'] || template['bodyText'] || template['content'] || 'Template content'
  end

  def extract_components(template)
    return {} unless template['components'].is_a?(Array)
    
    components = {}
    template['components'].each do |component|
      type = component['type']&.downcase
      components[type] = component if type
    end
    components
  end

  def extract_variables(template)
    variables = []
    
    if template['components']&.is_a?(Array)
      template['components'].each do |component|
        next unless component['parameters']&.is_a?(Array)
        
        component['parameters'].each_with_index do |param, index|
          variables << {
            'name' => "var_#{index + 1}",
            'type' => param['type'] || 'text',
            'required' => false
          }
        end
      end
    end
    
    variables
  end

  def determine_template_type(template)
    return 'text' unless template['components']&.is_a?(Array)
    
    has_media = template['components'].any? { |c| c['type'] == 'HEADER' && c['format']&.in?(%w[IMAGE VIDEO DOCUMENT]) }
    has_buttons = template['components'].any? { |c| c['type'] == 'BUTTONS' }
    
    return 'interactive' if has_buttons
    return 'media' if has_media
    
    'text'
  end

  def extract_settings(template)
    settings = {}
    settings['status'] = template['status'] if template['status']
    settings['source'] = template['source'] if template['source']
    settings['rejected_reason'] = template['rejected_reason'] if template['rejected_reason']
    settings
  end

  def extract_metadata(template)
    metadata = {}
    
    metadata['external_id'] = template['id'] if template['id']
    metadata['namespace'] = template['namespace'] if template['namespace']
    metadata['quality_score'] = template['quality_score'] if template['quality_score']
    metadata['created_at_source'] = template['created_at'] if template['created_at']
    metadata['updated_at_source'] = template['updated_at'] if template['updated_at']
    
    excluded_keys = %w[id name content text bodyText language category status components 
                       media_url media_type source rejected_reason namespace quality_score
                       created_at updated_at]
    template.except(*excluded_keys).each do |key, value|
      metadata[key] = value if value.present?
    end
    
    metadata
  end
end
