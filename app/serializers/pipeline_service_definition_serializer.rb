# frozen_string_literal: true

# PipelineServiceDefinitionSerializer - Optimized serialization for PipelineServiceDefinition resources
#
# Plain Ruby module for Oj direct serialization
#
# Usage:
#   PipelineServiceDefinitionSerializer.serialize(@service_definition)
#
module PipelineServiceDefinitionSerializer
  extend self

  # Serialize single PipelineServiceDefinition
  #
  # @param service_definition [PipelineServiceDefinition] Service definition to serialize
  # @param options [Hash] Serialization options
  #
  # @return [Hash] Serialized service definition ready for Oj
  #
  def serialize(service_definition, **_options)
    {
      id: service_definition.id,
      pipeline_id: service_definition.pipeline_id,
      name: service_definition.name,
      default_value: service_definition.default_value.to_f,
      currency: service_definition.currency,
      description: service_definition.description,
      active: service_definition.active,
      formatted_default_value: service_definition.formatted_default_value,
      created_at: service_definition.created_at&.iso8601,
      updated_at: service_definition.updated_at&.iso8601
    }
  end

  # Serialize collection of PipelineServiceDefinitions
  #
  # @param service_definitions [Array<PipelineServiceDefinition>, ActiveRecord::Relation]
  #
  # @return [Array<Hash>] Array of serialized service definitions
  #
  def serialize_collection(service_definitions, **options)
    return [] unless service_definitions

    service_definitions.map { |sd| serialize(sd, **options) }
  end
end
