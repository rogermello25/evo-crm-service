class MailPresenter < SimpleDelegator
  attr_accessor :mail

  def initialize(mail, account = nil)
    super(mail)
    @mail = mail
    @account = account
  end

  def subject
    encode_to_unicode(@mail.subject)
  end

  # encode decoded mail text_part or html_part if mail is multipart email
  # encode decoded mail raw bodyt if mail is not multipart email but the body content is text/html
  def mail_content(mail_part)
    if multipart_mail_body?
      decoded_multipart_mail(mail_part)
    else
      text_html_mail(mail_part)
    end
  end

  # encodes mail if mail.parts is present
  # encodes mail content type is multipart
  def decoded_multipart_mail(mail_part)
    encoded = encode_to_unicode(mail_part&.decoded)

    encoded if text_mail_body? || html_mail_body?
  end

  # encodes mail raw body if mail.parts is empty
  # encodes mail raw body if mail.content_type is plain/text
  # encodes mail raw body if mail.content_type is html/text
  def text_html_mail(mail_part)
    decoded = mail_part&.decoded || @mail.decoded
    encoded = encode_to_unicode(decoded)

    encoded if html_mail_body? || text_mail_body?
  end

  def text_content
    @decoded_text_content = mail_content(text_part) || ''

    encoding = @decoded_text_content.encoding

    body = EmailReplyTrimmer.trim(@decoded_text_content)

    return {} if @decoded_text_content.blank? || !text_mail_body?

    @text_content ||= {
      full: mail_content(text_part),
      reply: @decoded_text_content,
      quoted: body.force_encoding(encoding).encode('UTF-8')
    }
  end

  def html_content
    encoded = mail_content(html_part) || ''
    @decoded_html_content = ::HtmlParser.parse_reply(encoded)

    return {} if @decoded_html_content.blank? || !html_mail_body?

    body = EmailReplyTrimmer.trim(@decoded_html_content)

    @html_content ||= {
      full: mail_content(html_part),
      reply: @decoded_html_content,
      quoted: body
    }
  end

  # check content disposition check
  # if inline, upload to AWS and and take the URL
  def attachments
    # ref : https://github.com/gorails-screencasts/action-mailbox-action-text/blob/master/app/mailboxes/posts_mailbox.rb
    Rails.logger.info "[MailPresenter] Extracting attachments - mail.attachments.count: #{mail.attachments.count}"

    mail.attachments.map do |attachment|
      Rails.logger.info "[MailPresenter] Processing attachment: #{attachment.filename}, content_type: #{attachment.content_type}"
      Rails.logger.info "[MailPresenter] Attachment has body?: #{attachment.body.present?}, body class: #{attachment.body.class}"

      # Handle content_transfer_encoding - can be String or Mail::Field
      content_transfer_encoding_value = if attachment.content_transfer_encoding.nil?
                                          nil
                                        elsif attachment.content_transfer_encoding.is_a?(String)
                                          attachment.content_transfer_encoding
                                        else
                                          attachment.content_transfer_encoding.value
                                        end
      Rails.logger.info "[MailPresenter] Content-Transfer-Encoding: #{content_transfer_encoding_value.inspect}"
      Rails.logger.info "[MailPresenter] Content-Disposition: #{attachment.content_disposition}"

      # For attachments in emails constructed from RFC822, we need to handle decoding carefully
      # Try multiple methods to get the binary content
      attachment_body = nil

      begin
        # Method 1: Try decoded (works for most cases)
        attachment_body = attachment.body.decoded
        Rails.logger.info "[MailPresenter] Successfully decoded attachment using .decoded, size: #{attachment_body.length} bytes"

        # Check if decoded size seems too small (likely corruption)
        # If Content-Transfer-Encoding is base64 and size is suspiciously small (< 100 bytes),
        # try alternative methods
        if content_transfer_encoding_value&.downcase == 'base64' && attachment_body.length < 100
          Rails.logger.warn "[MailPresenter] Decoded size (#{attachment_body.length} bytes) seems too small for base64 attachment, trying alternative methods"
          raise StandardError, "Suspiciously small decoded size"
        end
      rescue StandardError => e
        Rails.logger.warn "[MailPresenter] Failed to decode attachment using .decoded: #{e.message}"
        Rails.logger.warn "[MailPresenter] Error class: #{e.class}, backtrace: #{e.backtrace.first(3).join(', ')}"

        begin
          # Method 2: Try raw_source and decode manually if needed
          raw_source = attachment.body.raw_source
          Rails.logger.info "[MailPresenter] Got raw_source, length: #{raw_source.length}, encoding: #{raw_source.encoding.name}"

          attachment_body = raw_source
          # If it's base64 encoded, decode it
          if content_transfer_encoding_value&.downcase == 'base64'
            Rails.logger.info "[MailPresenter] Decoding base64 content from raw_source"
            attachment_body = Base64.decode64(attachment_body)
            Rails.logger.info "[MailPresenter] After base64 decode, length: #{attachment_body.length}"
          end
        rescue StandardError => e2
          Rails.logger.warn "[MailPresenter] Failed to get attachment using .raw_source: #{e2.message}"

          begin
            # Method 3: Try accessing through part if available
            if attachment.respond_to?(:part) && attachment.part
              Rails.logger.info "[MailPresenter] Trying to access through attachment.part"
              attachment_body = attachment.part.body.decoded

              # If still too small, try raw_source from part
              if attachment_body.length < 100 && attachment.part.body.respond_to?(:raw_source)
                Rails.logger.info "[MailPresenter] Part decoded size still small, trying part.raw_source"
                part_raw = attachment.part.body.raw_source
                if content_transfer_encoding_value&.downcase == 'base64'
                  attachment_body = Base64.decode64(part_raw)
                else
                  attachment_body = part_raw
                end
              end
            else
              # Method 4: Try to_s as last resort (may not work for binary)
              attachment_body = attachment.body.to_s
              Rails.logger.warn "[MailPresenter] Using .to_s as fallback, length: #{attachment_body.length}"
            end
          rescue StandardError => e3
            Rails.logger.error "[MailPresenter] All methods failed: #{e3.message}"
            attachment_body = nil
          end
        end
      end

      # Ensure we have content
      unless attachment_body.present?
        Rails.logger.error "[MailPresenter] Could not extract attachment body for #{attachment.filename}"
        next
      end

      # Ensure binary encoding for all attachments
      attachment_body = attachment_body.force_encoding('ASCII-8BIT') if attachment_body.encoding != Encoding::ASCII_8BIT

      # Log attachment info for debugging
      Rails.logger.info "[MailPresenter] Final attachment: #{attachment.filename}, size: #{attachment_body.length} bytes, content_type: #{attachment.content_type}, encoding: #{attachment_body.encoding.name}"

      # Validate attachment size (should be > 0)
      if attachment_body.length == 0
        Rails.logger.error "[MailPresenter] Attachment #{attachment.filename} has zero length, skipping"
        next
      end

      # Warn if attachment size seems suspiciously small (likely corruption)
      if attachment_body.length < 100 && content_transfer_encoding_value&.downcase == 'base64'
        Rails.logger.warn "[MailPresenter] WARNING: Attachment #{attachment.filename} size (#{attachment_body.length} bytes) seems too small for a base64-encoded file. This may indicate corruption."
      end

      # Create StringIO with binary data
      io = StringIO.new(attachment_body)

      blob = ActiveStorage::Blob.create_and_upload!(
        io: io,
        filename: attachment.filename.presence || "attachment_#{SecureRandom.hex(4)}",
        content_type: attachment.content_type
      )

      Rails.logger.info "[MailPresenter] Successfully created blob for #{attachment.filename}, blob size: #{blob.byte_size} bytes"

      { original: attachment, blob: blob }
    end.compact
  end

  def number_of_attachments
    mail.attachments.count
  end

  def serialized_data
    {
      bcc: bcc,
      cc: cc,
      content_type: content_type,
      date: date,
      from: from,
      html_content: html_content,
      in_reply_to: in_reply_to,
      message_id: message_id,
      multipart: multipart?,
      number_of_attachments: number_of_attachments,
      subject: subject,
      text_content: text_content,
      to: to
    }
  end

  def in_reply_to
    return if @mail.in_reply_to.blank?

    # Although the "in_reply_to" field in the email can potentially hold multiple values,
    # our current system does not have the capability to handle this.
    # FIX ME: Address this issue by returning the complete results and utilizing them for querying conversations.
    @mail.in_reply_to.is_a?(Array) ? @mail.in_reply_to.first : @mail.in_reply_to
  end

  def from
    # changing to downcase to avoid case mismatch while finding contact
    from_addresses = @mail.reply_to.presence || @mail.from
    return [] if from_addresses.nil?
    from_addresses.is_a?(Array) ? from_addresses.map(&:downcase) : [from_addresses.to_s.downcase]
  end

  def sender_name
    Mail::Address.new((@mail[:reply_to] || @mail[:from]).value).name
  end

  def original_sender
    # Try reply_to first
    if @mail[:reply_to].try(:value).present?
      return from_email_address(@mail[:reply_to].value)
    end

    # Try X-Original-Sender header
    if @mail['X-Original-Sender'].try(:value).present?
      return from_email_address(@mail['X-Original-Sender'].value)
    end

    # Try from field
    if from.present? && from.first.present?
      return from_email_address(from.first)
    end

    # Fallback: try to extract from mail.from directly
    if @mail.from.present?
      from_addr = @mail.from.is_a?(Array) ? @mail.from.first : @mail.from
      return from_email_address(from_addr.to_s) if from_addr.present?
    end

    nil
  rescue StandardError => e
    Rails.logger.warn("[MailPresenter] Error extracting original_sender: #{e.message}")
    nil
  end

  def from_email_address(email)
    return nil if email.blank?
    Mail::Address.new(email.to_s).address
  end

  def email_forwarded_for
    @mail['X-Forwarded-For'].try(:value)
  end

  def mail_receiver
    if @mail.to.blank?
      return [email_forwarded_for] if email_forwarded_for.present?

      []
    else
      @mail.to
    end
  end

  def auto_reply?
    auto_submitted? || x_auto_reply?
  end

  def notification_email_from_evolution?
    # notification emails are send via mailer sender email address. so it should match
    sender_email = GlobalConfigService.load('MAILER_SENDER_EMAIL', nil) if defined?(GlobalConfigService)
    sender_email = sender_email.presence || ENV.fetch('MAILER_SENDER_EMAIL', 'Evolution <accounts@evoai.app>')
    original_sender == Mail::Address.new(sender_email).address
  end

  private

  def auto_submitted?
    @mail['Auto-Submitted'].present? && @mail['Auto-Submitted'].value != 'no'
  end

  def x_auto_reply?
    @mail['X-Autoreply'].present? && @mail['X-Autoreply'].value == 'yes'
  end

  # forcing the encoding of the content to UTF-8 so as to be compatible with database and serializers
  def encode_to_unicode(str)
    return '' if str.blank?

    current_encoding = str.encoding.name
    return str if current_encoding == 'UTF-8'

    str.encode(current_encoding, 'UTF-8', invalid: :replace, undef: :replace, replace: '?')
  rescue StandardError
    ''
  end

  def html_mail_body?
    ((mail.content_type || '').include? 'text/html') || @mail.html_part&.content_type&.include?('text/html')
  end

  def text_mail_body?
    ((mail.content_type || '').include? 'text/plain') || @mail.text_part&.content_type&.include?('text/plain')
  end

  def multipart_mail_body?
    ((mail.content_type || '').include? 'multipart') || @mail.parts.any?
  end
end
