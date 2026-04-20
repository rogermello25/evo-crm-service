class Gmail::ProcessHistoryJob < ApplicationJob
  queue_as :urgent

  def perform(channel_id, new_history_id)
    Rails.logger.info "[GMAIL_PUSH] ProcessHistoryJob started - channel_id: #{channel_id}, new_history_id: #{new_history_id}"

    # Ensure EvolutionExceptionTracker is available (needed in Sidekiq)
    load Rails.root.join('lib', 'evolution_exception_tracker.rb').to_s unless defined?(EvolutionExceptionTracker)

    channel = Channel::Email.find(channel_id)
    Rails.logger.info "[GMAIL_PUSH] Channel found - email: #{channel.email}, google?: #{channel.google?}, push_enabled?: #{channel.push_enabled?}"

    unless channel.google? && channel.push_enabled?
      Rails.logger.warn "[GMAIL_PUSH] Channel #{channel.email} is not Google or push not enabled, skipping"
      return
    end

    gmail_service = Gmail::ApiService.new(channel: channel)

    # Get last processed history ID
    start_history_id = channel.provider_config['watch_history_id']
    Rails.logger.info "[GMAIL_PUSH] Start history ID from provider_config: #{start_history_id.inspect}"

    unless start_history_id
      Rails.logger.warn "[GMAIL_PUSH] No start historyId for #{channel.email}, performing full sync"
      perform_full_sync(channel, gmail_service, new_history_id)
      return
    end

    Rails.logger.info "[GMAIL_PUSH] Fetching history for #{channel.email} from #{start_history_id} to #{new_history_id}"

    # Fetch history changes - filter by INBOX label to get only inbox messages
    history_response = gmail_service.get_history(start_history_id: start_history_id, label_id: 'INBOX')
    Rails.logger.info "[GMAIL_PUSH] get_history returned - response present?: #{history_response.present?}, class: #{history_response.class if history_response}"

    unless history_response
      # History not found (404) - need full resync
      Rails.logger.warn "[GMAIL_PUSH] History expired for #{channel.email}, performing full sync"
      perform_full_sync(channel, gmail_service, new_history_id)
      return
    end

    Rails.logger.info "[GMAIL_PUSH] History response received - historyId: #{history_response.history_id}, history items count: #{history_response.history&.size || 0}"

    # Process new messages
    process_history_changes(channel, gmail_service, history_response)

    # Update last processed history ID
    channel.update!(
      provider_config: channel.provider_config.merge(
        'watch_history_id' => new_history_id
      )
    )

    Rails.logger.info "[GMAIL_PUSH] History processed for #{channel.email} - new historyId: #{new_history_id}"
  rescue OAuth2::Error => e
    Rails.logger.error "[GMAIL_PUSH] OAuth error for #{channel.email}: #{e.message}"
    channel.authorization_error!
  rescue StandardError => e
    Rails.logger.error "[GMAIL_PUSH] Error processing history: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    EvolutionExceptionTracker.new(e, account: nil).capture_exception
  end

  private

  def process_history_changes(channel, gmail_service, history_response)
    unless history_response.history
      Rails.logger.warn "[GMAIL_PUSH] History response has no history items for #{channel.email}"
      return
    end

    Rails.logger.info "[GMAIL_PUSH] Processing #{history_response.history.size} history items for #{channel.email}"

    message_ids = Set.new

    # Collect all new message IDs from history
    history_response.history.each_with_index do |history_item, index|
      Rails.logger.debug "[GMAIL_PUSH] History item #{index + 1}/#{history_response.history.size}: messages_added=#{history_item.messages_added&.size || 0}, labels_added=#{history_item.labels_added&.size || 0}"

      # Messages added
      if history_item.messages_added
        history_item.messages_added.each do |added|
          message_ids.add(added.message.id)
          Rails.logger.debug "[GMAIL_PUSH] Message added: #{added.message.id}"
        end
      end

      # Labels added (e.g., INBOX label added to existing message)
      if history_item.labels_added
        history_item.labels_added.each do |label_change|
          if label_change.label_ids&.include?('INBOX')
            message_ids.add(label_change.message.id)
            Rails.logger.debug "[GMAIL_PUSH] Label INBOX added to message: #{label_change.message.id}"
          end
        end
      end
    end

    Rails.logger.info "[GMAIL_PUSH] Found #{message_ids.size} new messages for #{channel.email}"

    if message_ids.empty?
      Rails.logger.info "[GMAIL_PUSH] No new messages to process for #{channel.email}"
      return
    end

    # Process each message
    message_ids.each do |message_id|
      Rails.logger.info "[GMAIL_PUSH] Processing message #{message_id} for #{channel.email}"
      process_message(channel, gmail_service, message_id)
    end
  end

  def process_message(channel, gmail_service, message_id)
    with_message_mutex(channel, message_id) do
      # Check if message already exists
      existing = channel.inbox.messages.find_by(source_id: message_id)
      if existing
        Rails.logger.debug "[GMAIL_PUSH] Message #{message_id} already exists, skipping"
        return
      end

      # Fetch full message in RFC822 format
      raw_email = gmail_service.get_message_raw(message_id: message_id)

      unless raw_email.present?
        Rails.logger.warn "[GMAIL_PUSH] Failed to fetch raw email for message #{message_id}"
        return
      end

      # Validate email has minimum required structure
      unless raw_email.is_a?(String) && raw_email.length > 0
        Rails.logger.warn "[GMAIL_PUSH] Invalid raw email format for message #{message_id}"
        return
      end

      # Log raw email headers before parsing
      Rails.logger.info "[GMAIL_PUSH] ========== RAW EMAIL DATA =========="
      Rails.logger.info "[GMAIL_PUSH] Message ID: #{message_id}"
      Rails.logger.info "[GMAIL_PUSH] Raw email length: #{raw_email.length} bytes"
      Rails.logger.info "[GMAIL_PUSH] Raw email encoding: #{raw_email.encoding.name}"

      # Extract and log headers from raw email
      begin
        headers_end = raw_email.index("\r\n\r\n") || raw_email.index("\n\n")
        if headers_end
          headers = raw_email[0..headers_end]
          Rails.logger.info "[GMAIL_PUSH] Email headers:\n#{headers}"

          # Validate headers contain at least From or To
          unless headers.match?(/^(From|To|from|to):/mi)
            Rails.logger.warn "[GMAIL_PUSH] Email headers appear invalid (no From/To), skipping"
            return
          end
        else
          Rails.logger.warn "[GMAIL_PUSH] Could not extract headers - email structure invalid"
          Rails.logger.info "[GMAIL_PUSH] First 500 chars (hex): #{raw_email[0..500].unpack('H*').first}"
          return
        end
      rescue StandardError => e
        Rails.logger.error "[GMAIL_PUSH] Error extracting headers: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        return
      end

      Rails.logger.info "[GMAIL_PUSH] ===================================="

      # Parse and process email using existing mailbox processor
      begin
        # Ensure email is UTF-8 compatible for parsing
        # Mail gem expects binary/ASCII-8BIT for RFC822 format
        # We'll keep it as binary but ensure it's valid before parsing
        email_to_parse = raw_email.dup

        # Log encoding info
        Rails.logger.info "[GMAIL_PUSH] Email encoding before parse: #{email_to_parse.encoding.name}"

        # Mail gem works best with binary encoding for RFC822
        # But we need to ensure the content is valid
        email_to_parse.force_encoding('ASCII-8BIT') unless email_to_parse.encoding == Encoding::ASCII_8BIT

        mail = Mail.read_from_string(email_to_parse)

        # Validate parsed mail has required fields
        unless mail.from.present? || mail.reply_to.present?
          Rails.logger.warn "[GMAIL_PUSH] Parsed mail has no From or Reply-To, skipping"
          return
        end

        # Log parsed mail object details
        Rails.logger.info "[GMAIL_PUSH] Parsed mail - From: #{mail.from.inspect}, To: #{mail.to.inspect}, Subject: #{mail.subject.inspect}"
        Rails.logger.info "[GMAIL_PUSH] Parsed mail - Reply-To: #{mail.reply_to.inspect}, Date: #{mail.date.inspect}"
        Rails.logger.info "[GMAIL_PUSH] Parsed mail - Content-Type: #{mail.content_type.inspect}"
        Rails.logger.info "[GMAIL_PUSH] Parsed mail - Multipart?: #{mail.multipart?}, Parts count: #{mail.parts.count}"

        # Log text and html parts if available
        if mail.text_part
          text_content_preview = mail.text_part.decoded&.first(100) || 'nil'
          Rails.logger.info "[GMAIL_PUSH] Parsed mail - Text part present, preview: #{text_content_preview.inspect}"
        end
        if mail.html_part
          html_content_preview = mail.html_part.decoded&.first(100) || 'nil'
          Rails.logger.info "[GMAIL_PUSH] Parsed mail - HTML part present, preview: #{html_content_preview.inspect}"
        end

        inbound_mail = create_inbound_mail(mail, message_id)

        Imap::ImapMailbox.new.process(inbound_mail, channel)

        Rails.logger.info "[GMAIL_PUSH] Processed message #{message_id} for #{channel.email}"
      rescue Mail::Field::ParseError => e
        Rails.logger.error "[GMAIL_PUSH] Failed to parse email headers: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        return
      rescue StandardError => e
        Rails.logger.error "[GMAIL_PUSH] Failed to parse email: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        return
      end
    end
  rescue StandardError => e
    Rails.logger.error "[GMAIL_PUSH] Failed to process message #{message_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    EvolutionExceptionTracker.new(e, account: nil).capture_exception
    # Don't re-raise - continue processing other messages
  end

  def with_message_mutex(channel, message_id)
    inbox_id = channel.inbox&.id
    return yield if inbox_id.blank?

    lock_key = "GMAIL_PUSH_MESSAGE_LOCK::#{inbox_id}::#{message_id}"
    acquired = false
    acquired = ::Redis::Alfred.set(lock_key, job_id || Time.now.to_f.to_s, nx: true, ex: 10.minutes)

    unless acquired
      Rails.logger.info "[GMAIL_PUSH] Message #{message_id} is already being processed for inbox #{inbox_id}, skipping"
      return
    end

    yield
  ensure
    ::Redis::Alfred.delete(lock_key) if acquired
  end

  def perform_full_sync(channel, gmail_service, new_history_id)
    Rails.logger.info "[GMAIL_PUSH] Performing full sync for #{channel.email}"

    # List recent unread messages
    messages_response = gmail_service.list_messages(query: 'is:unread', max_results: 50)

    return unless messages_response.messages

    Rails.logger.info "[GMAIL_PUSH] Found #{messages_response.messages.size} unread messages"

    messages_response.messages.each do |message|
      process_message(channel, gmail_service, message.id)
    end

    # Update history ID after sync
    channel.update!(
      provider_config: channel.provider_config.merge(
        'watch_history_id' => new_history_id
      )
    )
  end

  def create_inbound_mail(mail, message_id)
    # The Mail object already has all the information we need
    # MailPresenter will handle multipart emails correctly
    # We just need to ensure message_id is set if not present
    mail.message_id ||= message_id if message_id.present?
    mail
  end
end
