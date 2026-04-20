# frozen_string_literal: true

# CustomAttributeDefinitionSerializer - Optimized serialization for CustomAttributeDefinition resources
#
# Plain Ruby module for Oj direct serialization
#
# Usage:
#   CustomAttributeDefinitionSerializer.serialize(@custom_attribute_definition)
#
module CustomAttributeDefinitionSerializer
  extend self

  # Serialize single CustomAttributeDefinition
  #
  # @param custom_attribute_definition [CustomAttributeDefinition] CustomAttributeDefinition to serialize
  # @param options [Hash] Serialization options
  #
  # @return [Hash] Serialized custom attribute definition ready for Oj
  #
  def serialize(custom_attribute_definition)
    {
      id: custom_attribute_definition.id,
      attribute_display_name: custom_attribute_definition.attribute_display_name,
      attribute_description: custom_attribute_definition.attribute_description,
      attribute_key: custom_attribute_definition.attribute_key,
      attribute_display_type: custom_attribute_definition.attribute_display_type,
      attribute_model: custom_attribute_definition.attribute_model,
      default_value: custom_attribute_definition.default_value,
      attribute_values: custom_attribute_definition.attribute_values,
      regex_pattern: custom_attribute_definition.regex_pattern,
      regex_cue: custom_attribute_definition.regex_cue,
      created_at: custom_attribute_definition.created_at&.iso8601,
      updated_at: custom_attribute_definition.updated_at&.iso8601
    }
  end

  # Serialize collection of CustomAttributeDefinitions
  #
  # @param custom_attribute_definitions [Array<CustomAttributeDefinition>, ActiveRecord::Relation]
  #
  # @return [Array<Hash>] Array of serialized custom attribute definitions
  #
  def serialize_collection(custom_attribute_definitions)
    return [] unless custom_attribute_definitions

    custom_attribute_definitions.map { |definition| serialize(definition) }
  end
end
