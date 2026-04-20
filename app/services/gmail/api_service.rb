require 'google/apis/gmail_v1'
require 'googleauth'

class Gmail::ApiService
  attr_reader :channel

  def initialize(channel:)
    @channel = channel
    @service = Google::Apis::GmailV1::GmailService.new
    @service.authorization = authorization
  end

  # Enable Gmail push notifications
  def watch_mailbox(topic_name: nil, label_ids: ['INBOX'])
    topic = topic_name || default_topic_name

    request = Google::Apis::GmailV1::WatchRequest.new(
      topic_name: topic,
      label_ids: label_ids,
      label_filter_action: 'include'
    )

    response = @service.watch_user('me', request)

    # Save watch info in provider_config
    channel.update!(
      provider_config: channel.provider_config.merge(
        'watch_history_id' => response.history_id,
        'watch_expiration' => response.expiration.to_i,
        'watch_topic' => topic
      )
    )

    response
  rescue Google::Apis::Error => e
    Rails.logger.error "[GMAIL_PUSH] Failed to watch mailbox: #{e.message}"
    raise
  end

  # Stop watching mailbox
  def stop_watch
    @service.stop_user('me')
    Rails.logger.info "[GMAIL_PUSH] Watch stopped for #{channel.email}"
  rescue Google::Apis::Error => e
    Rails.logger.error "[GMAIL_PUSH] Failed to stop watch: #{e.message}"
  end

  # Fetch history changes since last historyId
  def get_history(start_history_id:, label_id: nil, max_results: 100)
    options = {
      start_history_id: start_history_id.to_s,
      max_results: max_results,
      history_types: ['messageAdded', 'labelAdded']
    }
    options[:label_id] = label_id if label_id

    @service.list_user_histories('me', **options)
  rescue Google::Apis::ClientError => e
    if e.status_code == 404
      Rails.logger.warn "[GMAIL_PUSH] History not found (404) - resync needed for #{channel.email}"
      nil
    else
      raise
    end
  end

  # Get full message by ID
  def get_message(message_id:, format: 'full')
    @service.get_user_message('me', message_id, format: format)
  end

  # Get message in RFC822 format for processing
  def get_message_raw(message_id:)
    # Try raw format first (most efficient)
    begin
      message = @service.get_user_message('me', message_id, format: 'raw')
      return nil unless message&.raw

      # Handle base64 decoding with padding if needed
      raw_data = message.raw
      # Add padding if needed (base64 strings should be multiples of 4)
      raw_data += '=' * (4 - raw_data.length % 4) if raw_data.length % 4 != 0

      decoded = Base64.urlsafe_decode64(raw_data)

      # Validate decoded email has valid headers
      if decoded.include?('From:') || decoded.include?('from:')
        return decoded
      else
        Rails.logger.warn "[GMAIL_PUSH] Decoded raw email appears invalid (no From header), trying full format"
        raise ArgumentError, "Invalid decoded email structure"
      end
    rescue ArgumentError => e
      Rails.logger.error "[GMAIL_PUSH] Invalid base64 for message #{message_id}: #{e.message}"
      # Try standard base64 decode as fallback
      begin
        decoded = Base64.decode64(message.raw)
        if decoded.include?('From:') || decoded.include?('from:')
          return decoded
        else
          Rails.logger.warn "[GMAIL_PUSH] Standard decode also invalid, trying full format"
          raise ArgumentError, "Invalid decoded email structure"
        end
      rescue ArgumentError => e2
        Rails.logger.warn "[GMAIL_PUSH] Both urlsafe and standard base64 decode failed: #{e2.message}"
        Rails.logger.info "[GMAIL_PUSH] Falling back to full format for message #{message_id}"
        # Fall through to full format
      end
    end

    # Fallback: Use full format and construct RFC822 manually
    begin
      message = @service.get_user_message('me', message_id, format: 'full')
      return nil unless message

      construct_rfc822_from_full(message)
    rescue StandardError => e
      Rails.logger.error "[GMAIL_PUSH] Failed to get message #{message_id} in any format: #{e.message}"
      nil
    end
  end

  # Construct RFC822 email from Gmail full format message
  def construct_rfc822_from_full(message)
    headers = []

    # Extract headers from payload
    if message.payload&.headers
      message.payload.headers.each do |header|
        header_line = "#{header.name}: #{header.value}"
        headers << header_line
      end
    end

    # Build email body from parts (keep as binary for Mail gem)
    # Pass message.id so we can fetch attachments if needed
    body_parts = extract_body_from_parts(message.payload, message_id: message.id)

    # Combine headers and body
    # Keep everything in ASCII-8BIT (binary) - Mail gem expects this format
    headers_str = headers.join("\r\n")
    # Ensure headers_str is ASCII-8BIT before concatenation to avoid encoding errors
    headers_str = headers_str.force_encoding('ASCII-8BIT') unless headers_str.encoding == Encoding::ASCII_8BIT
    separator = "\r\n\r\n".force_encoding('ASCII-8BIT')
    email_content = headers_str + separator + body_parts

    # Ensure binary encoding for Mail gem (should already be ASCII-8BIT, but double-check)
    email_content.force_encoding('ASCII-8BIT') unless email_content.encoding == Encoding::ASCII_8BIT

    email_content
  end

  # Get attachment content by attachmentId
  def get_attachment(message_id:, attachment_id:)
    @service.get_user_message_attachment('me', message_id, attachment_id)
  rescue Google::Apis::Error => e
    Rails.logger.error "[GMAIL_PUSH] Failed to get attachment #{attachment_id} for message #{message_id}: #{e.message}"
    nil
  end

  # Extract body content from message parts recursively
  # Returns binary data (ASCII-8BIT) - Mail gem will handle encoding conversion
  def extract_body_from_parts(part, message_id: nil)
    return ''.force_encoding('ASCII-8BIT') unless part

    # If this part has body data directly, decode and return it as binary
    if part.body&.data
      decoded_body = decode_part_body(part.body.data)
      return decoded_body if decoded_body.present?
    end

    # If this part has an attachmentId (large attachments), fetch it separately
    if part.body&.attachment_id && message_id
      begin
        attachment = get_attachment(message_id: message_id, attachment_id: part.body.attachment_id)
        if attachment&.data
          decoded_body = decode_part_body(attachment.data)
          return decoded_body if decoded_body.present?
        end
      rescue StandardError => e
        Rails.logger.error "[GMAIL_PUSH] Failed to fetch attachment #{part.body.attachment_id}: #{e.message}"
      end
    end

    # If this part has sub-parts (multipart), process them
    if part.parts && part.parts.any?
      # For multipart messages, we need to construct proper boundaries
      boundary = extract_boundary(part) || "----=_Part_#{rand(1000000)}_#{Time.now.to_i}"

      parts_content = part.parts.map.with_index do |p, idx|
        part_headers = []
        content_transfer_encoding = nil
        if p.headers
          p.headers.each do |h|
            part_headers << "#{h.name}: #{h.value}"
            content_transfer_encoding = h.value if h.name.downcase == 'content-transfer-encoding'
          end
        end

        part_body = extract_body_from_parts(p, message_id: message_id)
        # Skip empty parts to avoid breaking structure
        next nil if part_body.blank?

        # Handle Content-Transfer-Encoding when constructing RFC822 manually
        # - base64: Need to encode in base64 (Mail gem expects base64 when header says base64)
        # - quoted-printable, 7bit, 8bit, binary: Content is already in correct format (no encoding needed)
        #   Mail gem will handle decoding automatically when parsing the RFC822
        if content_transfer_encoding&.downcase == 'base64'
          part_body = Base64.encode64(part_body)
          # Base64.encode64 adds newlines every 60 chars, which is RFC822 compliant
          part_body.force_encoding('ASCII-8BIT') unless part_body.encoding == Encoding::ASCII_8BIT
        else
          # For other encodings (quoted-printable, 7bit, 8bit, binary, or nil),
          # the content is already in the correct format - Mail gem will handle it
        end

        # Build separator ensuring all parts are ASCII-8BIT before concatenation
        boundary_str = boundary.to_s.force_encoding('ASCII-8BIT')
        headers_str = part_headers.join("\r\n").force_encoding('ASCII-8BIT')
        separator_newline = "\r\n".force_encoding('ASCII-8BIT')
        part_separator = "--#{boundary_str}#{separator_newline}#{headers_str}#{separator_newline}#{separator_newline}"
        part_separator + part_body
      end.compact.join("\r\n".force_encoding('ASCII-8BIT'))

      # Only add closing boundary if we have content
      if parts_content.present?
        # Ensure boundary and separator are ASCII-8BIT before concatenation
        boundary_str = boundary.to_s.force_encoding('ASCII-8BIT')
        closing_separator = "\r\n--#{boundary_str}--".force_encoding('ASCII-8BIT')
        parts_content += closing_separator
        # Ensure result is binary
        parts_content.force_encoding('ASCII-8BIT') unless parts_content.encoding == Encoding::ASCII_8BIT
        return parts_content
      end
    end

    ''.force_encoding('ASCII-8BIT')
  end

  # Decode part body data with multiple fallback strategies
  def decode_part_body(data)
    return ''.force_encoding('ASCII-8BIT') if data.blank?

    data_str = data.to_s

    # Strategy 0: Check if data is already decoded (text, not base64)
    # Indicators that data is already decoded:
    # 1. Contains HTML tags (<, >)
    # 2. Contains common text characters that aren't in base64 (like <, >, ", etc.)
    # 3. Very short strings (< 20 chars) with newlines are likely text
    # 4. Contains characters outside base64 charset

    # Check for HTML tags or other non-base64 characters
    if data_str.include?('<') || data_str.include?('>') || data_str.include?('"') || data_str.include?("'")
      binary_data = data_str.force_encoding('ASCII-8BIT')
      return binary_data
    end

    # Check for very short strings with newlines (likely plain text)
    if data_str.length < 20 && (data_str.include?("\r\n") || data_str.include?("\n"))
      binary_data = data_str.force_encoding('ASCII-8BIT')
      return binary_data
    end

    # Strategy 1: Try urlsafe base64 decode
    begin
      # Add padding if needed
      padded_data = data_str.dup
      padded_data += '=' * (4 - padded_data.length % 4) if padded_data.length % 4 != 0
      decoded = Base64.urlsafe_decode64(padded_data)
      decoded.force_encoding('ASCII-8BIT') unless decoded.encoding == Encoding::ASCII_8BIT

      # Validate decoded result - just check if it's not empty
      # Don't validate for printable characters as binary files (images, PDFs, etc.) contain non-printable bytes
      if decoded.length > 0
        return decoded
      else
        raise ArgumentError, "Empty decoded result"
      end
    rescue ArgumentError => e
      Rails.logger.warn "[GMAIL_PUSH] urlsafe_decode64 failed: #{e.message}"
    end

    # Strategy 2: Try standard base64 decode
    begin
      decoded = Base64.decode64(data_str)
      decoded.force_encoding('ASCII-8BIT') unless decoded.encoding == Encoding::ASCII_8BIT

      # Validate decoded result - just check if it's not empty
      # Don't validate for printable characters as binary files (images, PDFs, etc.) contain non-printable bytes
      if decoded.length > 0
        return decoded
      else
        raise ArgumentError, "Empty decoded result"
      end
    rescue ArgumentError => e
      Rails.logger.warn "[GMAIL_PUSH] decode64 failed: #{e.message}"
    end

    # Strategy 3: If all else fails, return as-is (might be already decoded)
    binary_data = data_str.force_encoding('ASCII-8BIT')
    binary_data
  end

  # Extract boundary from Content-Type header
  def extract_boundary(part)
    return nil unless part.headers

    content_type_header = part.headers.find { |h| h.name.downcase == 'content-type' }
    return nil unless content_type_header

    match = content_type_header.value.match(/boundary=["']?([^"'\s;]+)["']?/i)
    match ? match[1] : nil
  end

  # Ensure string is UTF-8 encoded, handling encoding issues
  def ensure_utf8_encoding(str)
    return '' if str.nil? || str.empty?

    # Convert to string if not already
    str = str.to_s unless str.is_a?(String)

    # If already UTF-8 and valid, return as is
    return str if str.encoding == Encoding::UTF_8 && str.valid_encoding?

    # Try to convert to UTF-8
    begin
      # For binary/ASCII-8BIT, try to detect if it's actually UTF-8
      if str.encoding == Encoding::ASCII_8BIT || str.encoding == Encoding::BINARY
        # Try to force UTF-8 encoding first (may be valid UTF-8 in binary encoding)
        test_str = str.dup.force_encoding('UTF-8')
        if test_str.valid_encoding?
          return test_str
        end

        # If that fails, try to detect encoding
        if defined?(CharDet)
          detected = CharDet.detect(str)
          source_encoding = detected&.encoding || 'ISO-8859-1'
        else
          # Default to ISO-8859-1 for binary data (common for email)
          source_encoding = 'ISO-8859-1'
        end

        # Convert from detected encoding to UTF-8
        str.force_encoding(source_encoding).encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      else
        # For other encodings, convert directly
        str.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      end
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
      Rails.logger.warn "[GMAIL_PUSH] Encoding conversion failed: #{e.message}, forcing UTF-8 with scrub"
      # Force UTF-8 and scrub invalid bytes
      str.force_encoding('UTF-8').scrub('?')
    rescue StandardError => e
      Rails.logger.error "[GMAIL_PUSH] Unexpected encoding error: #{e.message}"
      # Last resort: force UTF-8 and scrub
      str.force_encoding('UTF-8').scrub('?')
    end
  end

  # List messages (fallback for full sync)
  def list_messages(query: 'is:unread', max_results: 100)
    @service.list_user_messages('me', q: query, max_results: max_results)
  end

  # Mark message as read
  def mark_as_read(message_id:)
    modify_request = Google::Apis::GmailV1::ModifyMessageRequest.new(
      remove_label_ids: ['UNREAD']
    )
    @service.modify_message('me', message_id, modify_request)
  end

  # Send email
  def send_message(raw_email:)
    message = Google::Apis::GmailV1::Message.new(
      raw: Base64.urlsafe_encode64(raw_email)
    )
    @service.send_user_message('me', message)
  end

  private

  def authorization
    access_token = Google::RefreshOauthTokenService.new(channel: channel).access_token
    
    # Load OAuth credentials from GlobalConfig
    client_id = GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_ID', nil)
    client_secret = GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_SECRET', nil)

    auth = Signet::OAuth2::Client.new(
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      client_id: client_id,
      client_secret: client_secret,
      access_token: access_token,
      refresh_token: channel.provider_config['refresh_token']
    )

    auth
  end

  def default_topic_name
    project_id = ENV['GCP_PROJECT_ID']
    topic = ENV.fetch('GMAIL_PUBSUB_TOPIC', 'gmail-notifications')
    "projects/#{project_id}/topics/#{topic}"
  end
end
