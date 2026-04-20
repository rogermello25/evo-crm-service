# frozen_string_literal: true

# LabelSerializer - Optimized serialization for Label resources
#
# Plain Ruby module for Oj direct serialization
#
# Usage:
#   LabelSerializer.serialize(@label)
#
module LabelSerializer
  extend self

  # Serialize single Label (simple, no associations)
  #
  # @param label [Label] Label to serialize
  #
  # @return [Hash] Serialized label ready for Oj
  #
  def serialize(label)
    {
      id: label.id,
      title: label.title,
      description: label.description,
      color: label.color,
      show_on_sidebar: label.show_on_sidebar,
      created_at: label.created_at.to_i,
      updated_at: label.updated_at.to_i
    }
  end

  # Serialize collection of Labels
  #
  # @param labels [Array<Label>, ActiveRecord::Relation]
  #
  # @return [Array<Hash>] Array of serialized labels
  #
  def serialize_collection(labels)
    return [] unless labels

    labels.map { |label| serialize(label) }
  end
end
