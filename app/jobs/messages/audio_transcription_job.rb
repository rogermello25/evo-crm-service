class Messages::AudioTranscriptionJob < ApplicationJob
  queue_as :low

  def perform(attachment_id)
    attachment = Attachment.find_by(id: attachment_id)
    unless attachment
      Rails.logger.warn "AudioTranscriptionJob: Attachment not found: #{attachment_id}"
      return
    end

    unless attachment.audio?
      Rails.logger.info "AudioTranscriptionJob: Attachment #{attachment_id} is not audio (type: #{attachment.file_type})"
      return
    end

    unless attachment.message.incoming?
      Rails.logger.info "AudioTranscriptionJob: Attachment #{attachment_id} message is not incoming"
      return
    end

    Rails.logger.info "AudioTranscriptionJob: Starting transcription for attachment #{attachment_id}"
    result = Messages::AudioTranscriptionService.new(attachment: attachment).perform

    if result[:error]
      Rails.logger.warn "AudioTranscriptionJob: Transcription failed for attachment #{attachment_id}: #{result[:error]}"
    elsif result[:success]
      Rails.logger.info "AudioTranscriptionJob: Transcription successful for attachment #{attachment_id}"
    else
      Rails.logger.warn "AudioTranscriptionJob: Unexpected result for attachment #{attachment_id}: #{result.inspect}"
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn "AudioTranscriptionJob: Attachment not found for transcription: #{attachment_id}"
  rescue StandardError => e
    Rails.logger.error "AudioTranscriptionJob: Error processing attachment #{attachment_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end

