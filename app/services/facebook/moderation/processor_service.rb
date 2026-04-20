# Service to process moderation for messages
# Orchestrates the complete moderation flow:
# 1. Check explicit words (if enabled)
# 2. Check sentiment (if enabled)
# 3. Create moderation records for deletion or response approval
class Facebook::Moderation::ProcessorService
  attr_reader :message, :conversation, :agent_bot_inbox

  def initialize(message:, conversation:, agent_bot_inbox:)
    @message = message
    @conversation = conversation
    @agent_bot_inbox = agent_bot_inbox
  end

  def process
    Rails.logger.info "[Facebook Moderation] Starting process - moderation_enabled?: #{agent_bot_inbox.moderation_enabled?}, message_id: #{message.id}, conversation_id: #{conversation.id}"

    return unless agent_bot_inbox.moderation_enabled?

    Rails.logger.info "[Facebook Moderation] Processing moderation for message #{message.id} in conversation #{conversation.id}, content: #{message.content.inspect}"

    # Step 1: Check explicit words
    if agent_bot_inbox.should_check_explicit_words?
      explicit_words_result = check_explicit_words
      if explicit_words_result[:found]
        Rails.logger.info "[Facebook Moderation] Explicit words found: #{explicit_words_result[:matched_patterns].inspect}"

        if agent_bot_inbox.should_auto_reject_explicit_words?
          Rails.logger.info "[Facebook Moderation] Auto-reject enabled for explicit words, automatically rejecting and deleting"
          auto_reject_and_delete('explicit_words')
        else
          create_deletion_moderation('explicit_words')
        end

        return # Stop processing if explicit words found
      end
    end

    # Step 2: Check sentiment
    sentiment_result = nil
    if agent_bot_inbox.should_check_sentiment?
      Rails.logger.info "[Facebook Moderation] Sentiment analysis enabled, checking sentiment for: #{message.content.inspect}"
      sentiment_result = check_sentiment
      Rails.logger.info "[Facebook Moderation] Sentiment analysis result: #{sentiment_result.inspect}"
      if sentiment_result[:offensive]
        Rails.logger.info "[Facebook Moderation] Offensive sentiment detected: #{sentiment_result[:reason]}"

        if agent_bot_inbox.should_auto_reject_offensive_sentiment?
          Rails.logger.info "[Facebook Moderation] Auto-reject enabled for offensive sentiment, automatically rejecting and deleting"
          auto_reject_and_delete('offensive_sentiment', sentiment_result[:reason], sentiment_result)
        else
          create_deletion_moderation('offensive_sentiment', sentiment_result[:reason], sentiment_result)
        end

        return # Stop processing if offensive
      else
        Rails.logger.info "[Facebook Moderation] Sentiment analysis: Message is not offensive (confidence: #{sentiment_result[:confidence]})"
      end
    else
      Rails.logger.info "[Facebook Moderation] Sentiment analysis disabled (should_check_sentiment?: #{agent_bot_inbox.should_check_sentiment?})"
    end

    # Step 3: Generate response if moderation requires approval
    if agent_bot_inbox.requires_response_approval?
      Rails.logger.info "[Facebook Moderation] Response approval required, creating placeholder moderation record first"

      # Create a placeholder moderation record IMMEDIATELY to prevent bot from responding
      # This ensures the AgentBotListener will see the pending record and skip bot response
      moderation_attrs = {
        conversation: conversation,
        message: message,
        account: nil,
        comment_id: message.source_id || message.id.to_s,
        moderation_type: 'response_approval',
        status: 'pending',
        action_type: 'send_response',
        response_content: nil # Will be filled by GenerateResponseJob
      }

      # Add sentiment analysis results if available
      if sentiment_result.present?
        moderation_attrs[:sentiment_offensive] = sentiment_result[:offensive] || false
        moderation_attrs[:sentiment_confidence] = sentiment_result[:confidence] || 0.0
        moderation_attrs[:sentiment_reason] = sentiment_result[:reason]
      end

      placeholder_moderation = FacebookCommentModeration.create!(moderation_attrs)
      Rails.logger.info "[Facebook Moderation] Created placeholder moderation record #{placeholder_moderation.id}, will generate response asynchronously"

      # Queue response generation job - it will update the placeholder record with the generated response
      Facebook::Moderation::GenerateResponseJob.perform_later(
        message.id,
        conversation.id,
        agent_bot_inbox.agent_bot_for_conversation(conversation)&.id,
        sentiment_result,
        placeholder_moderation.id
      )
    else
      Rails.logger.info "[Facebook Moderation] Auto-approve enabled, skipping moderation queue"
    end
  end

  private

  def check_explicit_words
    checker = Facebook::Moderation::ExplicitWordsChecker.new(
      comment_content: message.content,
      patterns: agent_bot_inbox.explicit_words_filter || []
    )
    checker.check
  end

  def check_sentiment
    analyzer = Facebook::Moderation::SentimentAnalysisService.new(
      comment_content: message.content,
      account: nil
    )
    analyzer.analyze
  end

  def create_deletion_moderation(moderation_type, reason = nil, sentiment_result = nil)
    # Determine action type based on moderation type
    # For now, default to delete_comment, but could be configurable
    action_type = moderation_type == 'explicit_words' ? 'delete_comment' : 'delete_comment'

    moderation_attrs = {
      conversation: conversation,
      message: message,
      account: nil,
      comment_id: message.source_id || message.id.to_s,
      moderation_type: moderation_type,
      status: 'pending',
      action_type: action_type,
      rejection_reason: reason
    }

    # Add sentiment analysis results if available
    if sentiment_result.present?
      moderation_attrs[:sentiment_offensive] = sentiment_result[:offensive] || false
      moderation_attrs[:sentiment_confidence] = sentiment_result[:confidence] || 0.0
      moderation_attrs[:sentiment_reason] = sentiment_result[:reason]
    end

    FacebookCommentModeration.create!(moderation_attrs)

    Rails.logger.info "[Facebook Moderation] Created deletion moderation record (type: #{moderation_type})"
  end

  def auto_reject_and_delete(moderation_type, reason = nil, sentiment_result = nil)
    Rails.logger.info "[Facebook Moderation] Auto-rejecting and deleting message (type: #{moderation_type})"

    # Create moderation record with rejected status
    moderation_attrs = {
      conversation: conversation,
      message: message,
      account: nil,
      comment_id: message.source_id || message.id.to_s,
      moderation_type: moderation_type,
      status: 'rejected',
      action_type: 'delete_comment',
      rejection_reason: reason || "Auto-rejected due to #{moderation_type}"
    }

    # Add sentiment analysis results if available
    if sentiment_result.present?
      moderation_attrs[:sentiment_offensive] = sentiment_result[:offensive] || false
      moderation_attrs[:sentiment_confidence] = sentiment_result[:confidence] || 0.0
      moderation_attrs[:sentiment_reason] = sentiment_result[:reason]
    end

    moderation = FacebookCommentModeration.create!(moderation_attrs)

    # Execute delete action immediately
    executor = Facebook::Moderation::ActionExecutorService.new(moderation)
    executor.delete_comment

    # Delete the message from the system
    if message.present?
      Rails.logger.info "[Facebook Moderation] Deleting message #{message.id} from system after auto-reject"
      begin
        message.destroy
        Rails.logger.info "[Facebook Moderation] Message #{message.id} deleted successfully from system"
      rescue StandardError => e
        Rails.logger.error "[Facebook Moderation] Error deleting message #{message.id} from system: #{e.message}"
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end

    Rails.logger.info "[Facebook Moderation] Auto-reject and delete completed (type: #{moderation_type})"
  end

end

