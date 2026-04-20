class Inboxes::ProcessEmailBatchJob < ApplicationJob
  queue_as :email_processing

  def perform(channel, email_batch)
    return unless channel.imap_enabled?

    Rails.logger.info "[PROCESS_EMAIL_BATCH] Processing #{email_batch.length} emails for inbox #{channel.inbox.id}"

    processed_count = 0
    failed_count = 0

    email_batch.each do |inbound_mail|
      begin
        Imap::ImapMailbox.new.process(inbound_mail, channel)
        processed_count += 1
      rescue StandardError => e
        failed_count += 1
        EvolutionExceptionTracker.new(e, account: nil).capture_exception
        Rails.logger.error "Failed to process email: #{inbound_mail&.message_id} - #{e.message}"
      end
    end

    Rails.logger.info "[PROCESS_EMAIL_BATCH] Completed: #{processed_count} processed, #{failed_count} failed"
  end
end
