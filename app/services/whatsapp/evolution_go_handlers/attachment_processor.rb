module Whatsapp::EvolutionGoHandlers::AttachmentProcessor
  private

  def process_attachment
    # In Evolution Go, attachment processing is handled directly in MessagesUpsert
    Rails.logger.debug 'Evolution Go API: Attachment processing handled in MessagesUpsert'
  end

  def process_attachment_media
    # Process media attachment using Evolution Go's media handling
    extract_media_url_and_attach
  end

  def extract_media_url_and_attach
    media_url = extract_media_url_from_evolution_go_message

    return if media_url.blank?

    attach_file_from_url(media_url)
  end

  def media_url
    # Extract media URL from Evolution Go message structure
    message_data = @raw_message[:message] || {}

    case @raw_message[:messageType]
    when 'imageMessage'
      message_data.dig(:imageMessage, :URL)
    when 'videoMessage'
      message_data.dig(:videoMessage, :URL)
    when 'audioMessage'
      message_data.dig(:audioMessage, :URL)
    when 'documentMessage'
      message_data.dig(:documentMessage, :URL)
    when 'stickerMessage'
      message_data.dig(:stickerMessage, :URL)
    end
  end
end
