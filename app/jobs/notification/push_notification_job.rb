class Notification::PushNotificationJob < ApplicationJob
  queue_as :default

  def perform(notification)
    Rails.logger.info("📱 [PUSH JOB] Starting push notification job for notification #{notification.id}, type: #{notification.notification_type}, user: #{notification.user&.email}")
    Notification::PushNotificationService.new(notification: notification).perform
    Rails.logger.info("📱 [PUSH JOB] Completed push notification job for notification #{notification.id}")
  end
end
