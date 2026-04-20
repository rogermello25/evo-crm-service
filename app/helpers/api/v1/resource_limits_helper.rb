# frozen_string_literal: true

module Api::V1::ResourceLimitsHelper
  def validate_agent_bot_limit
    # No account-level limits in community edition
  end

  def validate_pipeline_limit
    # No account-level limits in community edition
  end

  def validate_automation_limit
    # No account-level limits in community edition
  end

  def validate_team_limit
    # No account-level limits in community edition
  end

  def validate_channel_limit(channel_type)
    # No account-level limits in community edition
  end

  def validate_custom_attribute_limit(attribute_model)
    # No account-level limits in community edition
  end

  def validate_channel_limit_for_creation
    # No account-level limits in community edition
  end

  private

  def limit_is_unlimited?(_limit_value)
    true
  end
end
