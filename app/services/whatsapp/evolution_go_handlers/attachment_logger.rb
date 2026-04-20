module Whatsapp::EvolutionGoHandlers::AttachmentLogger
  private

  def log_attachment_details
    return unless @raw_message[:messageType]&.match?(/(image|video|audio|document|sticker)Message/)

    Rails.logger.info "Evolution Go: Processing #{@raw_message[:messageType]} attachment"
    Rails.logger.debug { "Evolution Go: Media URL: #{media_url}" }
  end
end
