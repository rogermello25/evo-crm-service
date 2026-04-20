module Whatsapp::EvolutionHandlers::AttachmentLogger
  def log_attachment_info(attachment_file, final_filename, final_content_type)
    Rails.logger.info 'Evolution API: Creating attachment with:'
    Rails.logger.info "  - Final filename: #{final_filename}"
    Rails.logger.info "  - Final content_type: #{final_content_type}"
    Rails.logger.info "  - File object class: #{attachment_file.class}"
    Rails.logger.info "  - File size: #{attachment_file.respond_to?(:size) ? attachment_file.size : 'unknown'}"
  end

  def log_attachment_success(attachment)
    Rails.logger.info "Evolution API: Successfully created attachment for message #{raw_message_id}"
    Rails.logger.info "Evolution API: Attachment ID: #{attachment.id}, File attached: #{attachment.file.attached?}"
  end

  def log_base64_processing(decoded_data, content_type, file_name)
    Rails.logger.info 'Evolution API: Creating attachment from base64'
    Rails.logger.info "  - Size: #{decoded_data.bytesize} bytes"
    Rails.logger.info "  - Content-Type: #{content_type}"
    Rails.logger.info "  - Filename: #{file_name}"
  end

  def log_tempfile_success(tempfile)
    Rails.logger.info "Evolution API: Successfully created tempfile: #{tempfile.path}"
    Rails.logger.info "Evolution API: Tempfile size: #{tempfile.size} bytes"
  end

  def log_base64_error(error, base64_data)
    Rails.logger.error "Evolution API: Failed to create file from base64: #{error.message}"
    Rails.logger.error "  - Base64 size: #{base64_data&.length || 0} chars"
    Rails.logger.error "  - Message type: #{message_type}"
    Rails.logger.error "  - Raw mimetype: #{message_mimetype}"
  end

  def debug_media_info
    message = @raw_message[:message]
    Rails.logger.info 'Evolution API: Media processing debug:'
    Rails.logger.info "  Message Type: #{message_type}"
    Rails.logger.info "  Has Base64: #{message[:base64].present?}"
    Rails.logger.info "  Has MediaUrl: #{message[:mediaUrl].present?}"
    Rails.logger.info "  MimeType: #{message_mimetype}"
    Rails.logger.info "  Filename: #{filename}"
    Rails.logger.info "  File Extension: #{file_extension}"
  end
end
