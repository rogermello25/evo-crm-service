class Crm::Bms::Mappers::CustomAttributeMapper
  def self.map(custom_attribute_definition)
    new(custom_attribute_definition).map
  end

  def initialize(custom_attribute_definition)
    @custom_attribute_definition = custom_attribute_definition
  end

  def map
    {
      type: map_attribute_type,
      attributionType: 'last', # BMS default attribution type
      fileFormats: [], # Empty for most field types
      title: custom_attribute_definition.attribute_key,
      description: build_description
    }
  end

  private

  attr_reader :custom_attribute_definition

  def map_attribute_type
    # Map Evolution attribute types to BMS custom field types
    case custom_attribute_definition.attribute_display_type
    when 'text', 'link', 'list'
      'text'
    when 'number', 'currency', 'percent'
      'number'
    when 'date'
      'date'
    when 'checkbox'
      'text' # BMS doesn't have boolean type, use text
    else
      'text' # Default to text for unknown types
    end
  end

  def build_description
    # Create a description based on the Evolution attribute
    description_parts = []

    # Add the attribute key for reference
    description_parts << "Evolution attribute: #{custom_attribute_definition.attribute_key}"

    # Add type information
    description_parts << "Type: #{custom_attribute_definition.attribute_display_type}"

    # Add model information
    model_name = custom_attribute_definition.attribute_model == 'contact_attribute' ? 'Contact' : 'Conversation'
    description_parts << "Model: #{model_name}"

    # Add any additional description if available
    if custom_attribute_definition.attribute_description.present?
      description_parts << "Description: #{custom_attribute_definition.attribute_description}"
    end

    description_parts.join(' | ')
  end
end
