module Whatsapp::EvolutionHandlers::FileExtensions
  def file_extension
    case message_type
    when 'image'
      image_extension
    when 'video'
      video_extension
    when 'audio'
      audio_extension
    when 'file'
      document_extension
    when 'sticker'
      '.webp'
    else
      '.bin'
    end
  end

  def determine_content_type
    mime = message_mimetype
    return mime if mime.present?

    default_content_types[message_type] || 'application/octet-stream'
  end

  def generate_filename_with_extension
    existing_filename = filename
    return existing_filename if existing_filename.present? && File.extname(existing_filename).present?

    base_name = existing_filename.presence || "#{message_type}_#{raw_message_id}_#{Time.current.strftime('%Y%m%d')}"
    extension = file_extension

    "#{base_name}#{extension}"
  end

  private

  def default_content_types
    {
      'image' => 'image/jpeg',
      'video' => 'video/mp4',
      'audio' => 'audio/mpeg',
      'file' => 'application/octet-stream',
      'sticker' => 'image/webp'
    }
  end

  def image_extension
    extension_map = {
      /jpeg/ => '.jpg',
      /png/ => '.png',
      /gif/ => '.gif',
      /webp/ => '.webp'
    }

    extension_map.each { |pattern, ext| return ext if message_mimetype&.match?(pattern) }
    '.jpg' # Fallback for images
  end

  def video_extension
    extension_map = {
      /mp4/ => '.mp4',
      /webm/ => '.webm',
      /avi/ => '.avi'
    }

    extension_map.each { |pattern, ext| return ext if message_mimetype&.match?(pattern) }
    '.mp4' # Fallback for videos
  end

  def audio_extension
    extension_map = {
      /mp3/ => '.mp3',
      /wav/ => '.wav',
      /ogg/ => '.ogg',
      /aac/ => '.aac',
      /opus/ => '.opus'
    }

    extension_map.each { |pattern, ext| return ext if message_mimetype&.match?(pattern) }
    '.mp3' # Fallback for audio files
  end

  def document_extension
    filename_from_message = @raw_message.dig(:message, :documentMessage, :fileName) ||
                            @raw_message.dig(:message, :documentWithCaptionMessage, :message, :documentMessage, :fileName)
    return File.extname(filename_from_message) if filename_from_message.present?

    extension_map = {
      /pdf/ => '.pdf',
      /doc/ => '.doc',
      /zip/ => '.zip'
    }

    extension_map.each { |pattern, ext| return ext if message_mimetype&.match?(pattern) }
    '.bin' # Fallback for document files
  end
end
