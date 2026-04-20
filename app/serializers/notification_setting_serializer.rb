# frozen_string_literal: true

# NotificationSettingSerializer - Optimized serialization for NotificationSetting resources
#
# Plain Ruby module for Oj direct serialization
#
# Usage:
#   NotificationSettingSerializer.serialize(@notification_setting)
#
module NotificationSettingSerializer
  extend self

  # Serialize single NotificationSetting
  #
  # @param notification_setting [NotificationSetting] NotificationSetting to serialize
  # @param options [Hash] Serialization options
  #
  # @return [Hash] Serialized notification setting ready for Oj
  #
  def serialize(notification_setting)
    {
      id: notification_setting.id,
      user_id: notification_setting.user_id,
      email_flags: notification_setting.email_flags,
      push_flags: notification_setting.push_flags,
      selected_email_flags: notification_setting.selected_email_flags,
      selected_push_flags: notification_setting.selected_push_flags,
      all_email_flags: all_email_flags,
      all_push_flags: all_push_flags,
      created_at: notification_setting.created_at&.iso8601,
      updated_at: notification_setting.updated_at&.iso8601
    }
  end

  private

  # Return only notification types that the mobile app supports
  # Excludes pipeline task notifications (20-23)
  def supported_notification_types
    Notification::NOTIFICATION_TYPES.select { |_key, value| value < 20 }.keys
  end

  def all_email_flags
    supported_notification_types.map { |key| "email_#{key}" }
  end

  def all_push_flags
    supported_notification_types.map { |key| "push_#{key}" }
  end

  # Serialize collection of NotificationSettings
  #
  # @param notification_settings [Array<NotificationSetting>, ActiveRecord::Relation]
  #
  # @return [Array<Hash>] Array of serialized notification settings
  #
  def serialize_collection(notification_settings)
    return [] unless notification_settings

    notification_settings.map { |setting| serialize(setting) }
  end
end
