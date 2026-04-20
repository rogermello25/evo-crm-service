# frozen_string_literal: true

class ScheduledActionNotificationJob < ApplicationJob
  queue_as :default

  def perform(notification_id)
    notification = ScheduledActionNotification.find(notification_id)

    # Send the notification to the user
    # This can be extended to send email, push notification, in-app notification, etc.
    send_notification(notification)

    # Mark as sent
    notification.mark_as_sent!
  rescue StandardError => e
    Rails.logger.error("Failed to send notification #{notification_id}: #{e.message}")
    notification&.mark_as_failed!(e)
    raise e
  end

  private

  def send_notification(notification)
    # TODO: Implement actual notification delivery
    # This could be:
    # - Email notification
    # - Push notification
    # - In-app notification
    # - WebSocket broadcast
    # - Slack/MS Teams webhook

    # For now, just log it
    Rails.logger.info(
      "Sending #{notification.notification_type} notification to user #{notification.user_id}: #{notification.message}"
    )

    # Broadcast to WebSocket if available
    broadcast_notification(notification)
  end

  def broadcast_notification(notification)
    ActionCable.server.broadcast(
      "user_#{notification.user_id}:notifications",
      {
        type: 'scheduled_action_notification',
        id: notification.id,
        notification_type: notification.notification_type,
        message: notification.message,
        scheduled_action_id: notification.scheduled_action_id,
        created_at: notification.created_at
      }
    )
  end
end
