class PipelineTasks::NotificationService
  def initialize(task:, notification_type:)
    @task = task
    @notification_type = notification_type.to_s
  end

  def perform
    return unless should_notify?

    create_notification
    send_email_notification if email_enabled?
    send_push_notification
  end

  private

  def should_notify?
    return false if @task.assigned_to.blank?

    # Don't notify if task is completed or cancelled
    return false if @task.status_completed? || @task.status_cancelled?

    true
  end

  def create_notification
    Notification.create!(
      user: @task.assigned_to,
      notification_type: @notification_type,
      primary_actor: @task,
      secondary_actor: @task.pipeline_item
    )
  end

  def send_email_notification
    case @notification_type
    when 'pipeline_task_assigned'
      PipelineTaskMailer.task_assigned(@task).deliver_later
    when 'pipeline_task_due_soon'
      PipelineTaskMailer.task_due_soon(@task).deliver_later
    when 'pipeline_task_overdue'
      PipelineTaskMailer.task_overdue(@task).deliver_later
    end
  end

  def send_push_notification
    return if @task.assigned_to.blank?

    Notification::PushNotificationService.new(
      user: @task.assigned_to,
      notification_type: @notification_type,
      primary_actor: @task
    ).perform
  rescue StandardError => e
    Rails.logger.error "[PipelineTaskNotificationService] Error sending push notification: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
  end

  def email_enabled?
    # Check user preferences or account settings
    # Default to true if no preference is set
    @task.assigned_to.notification_settings.dig('email', 'pipeline_tasks') != false
  rescue StandardError
    true # Default to sending email if there's an error checking preferences
  end
end
