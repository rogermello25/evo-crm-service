# frozen_string_literal: true

# CustomFilterSerializer - Optimized serialization for CustomFilter resources
#
# Plain Ruby module for Oj direct serialization
#
# Usage:
#   CustomFilterSerializer.serialize(@custom_filter)
#
module CustomFilterSerializer
  extend self

  # Serialize single CustomFilter
  #
  # @param custom_filter [CustomFilter] CustomFilter to serialize
  # @param options [Hash] Serialization options
  #
  # @return [Hash] Serialized custom filter ready for Oj
  #
  def serialize(custom_filter)
    {
      id: custom_filter.id,
      name: custom_filter.name,
      filter_type: custom_filter.filter_type,
      query: custom_filter.query,
      user_id: custom_filter.user_id,
      created_at: custom_filter.created_at&.iso8601,
      updated_at: custom_filter.updated_at&.iso8601
    }
  end

  # Serialize collection of CustomFilters
  #
  # @param custom_filters [Array<CustomFilter>, ActiveRecord::Relation]
  #
  # @return [Array<Hash>] Array of serialized custom filters
  #
  def serialize_collection(custom_filters)
    return [] unless custom_filters

    custom_filters.map { |filter| serialize(filter) }
  end
end
