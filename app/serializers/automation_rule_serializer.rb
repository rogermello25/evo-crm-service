# frozen_string_literal: true

# AutomationRuleSerializer - Optimized serialization for AutomationRule resources
#
# Plain Ruby module for Oj direct serialization
#
# Usage:
#   AutomationRuleSerializer.serialize(@automation_rule)
#
module AutomationRuleSerializer
  extend self

  # Serialize single AutomationRule
  #
  # @param automation_rule [AutomationRule] AutomationRule to serialize
  # @param options [Hash] Serialization options
  #
  # @return [Hash] Serialized automation rule ready for Oj
  #
  def serialize(automation_rule)
    {
      id: automation_rule.id,
      name: automation_rule.name,
      description: automation_rule.description,
      event_name: automation_rule.event_name,
      conditions: automation_rule.conditions,
      actions: automation_rule.actions,
      active: automation_rule.active,
      created_at: automation_rule.created_at&.iso8601,
      updated_at: automation_rule.updated_at&.iso8601
    }
  end

  # Serialize collection of AutomationRules
  #
  # @param automation_rules [Array<AutomationRule>, ActiveRecord::Relation]
  #
  # @return [Array<Hash>] Array of serialized automation rules
  #
  def serialize_collection(automation_rules)
    return [] unless automation_rules

    automation_rules.map { |rule| serialize(rule) }
  end
end
