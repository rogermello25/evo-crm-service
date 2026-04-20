# Background job to generate response for Facebook comment moderation
# Generates response using agent bot and updates placeholder moderation record with the response
class Facebook::Moderation::GenerateResponseJob < ApplicationJob
  queue_as :default

  def perform(message_id, conversation_id, agent_bot_id, sentiment_result = nil, moderation_id = nil)
    message = Message.find(message_id)
    conversation = Conversation.find(conversation_id)
    agent_bot = AgentBot.find(agent_bot_id)

    Rails.logger.info "[Facebook Moderation] GenerateResponseJob: Starting response generation for message #{message_id}, moderation_id: #{moderation_id}"

    # Use ResponseGeneratorService to generate response
    generator = Facebook::Moderation::ResponseGeneratorService.new(
      conversation: conversation,
      message: message,
      agent_bot: agent_bot
    )

    response_content = generator.generate

    unless response_content.present?
      Rails.logger.warn "[Facebook Moderation] GenerateResponseJob: No response content generated"
      # If we have a placeholder moderation record, delete it since we can't generate a response
      if moderation_id.present?
        begin
          moderation = FacebookCommentModeration.find(moderation_id)
          moderation.destroy
          Rails.logger.info "[Facebook Moderation] GenerateResponseJob: Deleted placeholder moderation record #{moderation_id} due to no response content"
        rescue ActiveRecord::RecordNotFound
          Rails.logger.warn "[Facebook Moderation] GenerateResponseJob: Placeholder moderation record #{moderation_id} not found"
        end
      end
      return
    end

    # If we have a placeholder moderation record, update it with the generated response
    if moderation_id.present?
      begin
        moderation = FacebookCommentModeration.find(moderation_id)
        moderation.update!(
          response_content: response_content,
          sentiment_offensive: sentiment_result&.dig(:offensive) || false,
          sentiment_confidence: sentiment_result&.dig(:confidence) || 0.0,
          sentiment_reason: sentiment_result&.dig(:reason)
        )
        Rails.logger.info "[Facebook Moderation] GenerateResponseJob: Updated placeholder moderation record #{moderation_id} with generated response"
      rescue ActiveRecord::RecordNotFound
        Rails.logger.warn "[Facebook Moderation] GenerateResponseJob: Placeholder moderation record #{moderation_id} not found, creating new record"
        # Fallback: create new record if placeholder was deleted
        moderation_attrs = {
          conversation: conversation,
          message: message,
          account: nil,
          comment_id: message.source_id || message.id.to_s,
          moderation_type: 'response_approval',
          status: 'pending',
          action_type: 'send_response',
          response_content: response_content
        }
        if sentiment_result.present?
          moderation_attrs[:sentiment_offensive] = sentiment_result[:offensive] || false
          moderation_attrs[:sentiment_confidence] = sentiment_result[:confidence] || 0.0
          moderation_attrs[:sentiment_reason] = sentiment_result[:reason]
        end
        moderation = FacebookCommentModeration.create!(moderation_attrs)
        Rails.logger.info "[Facebook Moderation] GenerateResponseJob: Created new moderation record #{moderation.id}"
      end
    else
      # Legacy: create new record if no placeholder was provided (backward compatibility)
      Rails.logger.warn "[Facebook Moderation] GenerateResponseJob: No moderation_id provided, creating new record (legacy mode)"
      moderation_attrs = {
        conversation: conversation,
        message: message,
        account: nil,
        comment_id: message.source_id || message.id.to_s,
        moderation_type: 'response_approval',
        status: 'pending',
        action_type: 'send_response',
        response_content: response_content
      }
      if sentiment_result.present?
        moderation_attrs[:sentiment_offensive] = sentiment_result[:offensive] || false
        moderation_attrs[:sentiment_confidence] = sentiment_result[:confidence] || 0.0
        moderation_attrs[:sentiment_reason] = sentiment_result[:reason]
      end
      moderation = FacebookCommentModeration.create!(moderation_attrs)
      Rails.logger.info "[Facebook Moderation] GenerateResponseJob: Created new moderation record #{moderation.id}"
    end

    Rails.logger.info "[Facebook Moderation] Response generated and queued for approval - moderation_id: #{moderation.id}"
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[Facebook Moderation] Record not found: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "[Facebook Moderation] Error generating response: #{e.message}"
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end
end

