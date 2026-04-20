class Gmail::ProcessPubsubNotificationJob < ApplicationJob
  queue_as :urgent

  def perform(notification_data)
    Rails.logger.info "[GMAIL_PUSH] ========== ProcessPubsubNotificationJob STARTED =========="
    Rails.logger.info "[GMAIL_PUSH] Job ID: #{job_id}"
    Rails.logger.info "[GMAIL_PUSH] Notification data class: #{notification_data.class}"
    Rails.logger.info "[GMAIL_PUSH] Notification data: #{notification_data.inspect}"
    Rails.logger.info "[GMAIL_PUSH] Notification data blank?: #{notification_data.blank?}"

    if notification_data.blank?
      Rails.logger.warn "[GMAIL_PUSH] Notification data is blank, exiting early"
      return
    end

    email_address = notification_data[:email_address] || notification_data['email_address']
    history_id = notification_data[:history_id] || notification_data['history_id']

    Rails.logger.info "[GMAIL_PUSH] Extracted - email_address: #{email_address.inspect}, history_id: #{history_id.inspect}"

    unless email_address.present? && history_id.present?
      Rails.logger.warn "[GMAIL_PUSH] Missing required fields - email_address present?: #{email_address.present?}, history_id present?: #{history_id.present?}"
      Rails.logger.warn "[GMAIL_PUSH] Full notification_data keys: #{notification_data.respond_to?(:keys) ? notification_data.keys.inspect : 'N/A'}"
      return
    end

    Rails.logger.info "[GMAIL_PUSH] Processing notification for #{email_address} - historyId: #{history_id}"

    # Find channel by email (case-insensitive)
    channel = Channel::Email.where("LOWER(email) = ?", email_address.downcase).find_by(provider: 'google')

    unless channel
      Rails.logger.warn "[GMAIL_PUSH] Channel not found for email: #{email_address}"
      all_google_channels = Channel::Email.where(provider: 'google').pluck(:email)
      Rails.logger.warn "[GMAIL_PUSH] Available Google channels (#{all_google_channels.count}): #{all_google_channels.inspect}"
      return
    end

    Rails.logger.info "[GMAIL_PUSH] Found channel: #{channel.id} for #{channel.email}"
    Rails.logger.info "[GMAIL_PUSH] Channel push_enabled?: #{channel.push_enabled?}"

    # Process history changes
    Rails.logger.info "[GMAIL_PUSH] Enqueuing ProcessHistoryJob for channel #{channel.id} with history_id #{history_id}"
    Gmail::ProcessHistoryJob.perform_later(channel.id, history_id)
    Rails.logger.info "[GMAIL_PUSH] ProcessHistoryJob enqueued successfully"
  rescue StandardError => e
    Rails.logger.error "[GMAIL_PUSH] ========== ERROR IN ProcessPubsubNotificationJob =========="
    Rails.logger.error "[GMAIL_PUSH] Error: #{e.class}: #{e.message}"
    Rails.logger.error "[GMAIL_PUSH] Backtrace:\n#{e.backtrace.join("\n")}"
    EvolutionExceptionTracker.new(e).capture_exception
    raise # Re-raise to ensure Sidekiq retries
  end
end
