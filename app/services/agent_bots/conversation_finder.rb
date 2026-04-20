class AgentBots::ConversationFinder
  def initialize(agent_bot, payload)
    @agent_bot = agent_bot
    @payload = payload
  end

  def find_conversation
    log_payload_debug_info

    if @payload.dig(:conversation, :id)
      find_conversation_by_id(@payload[:conversation][:id])
    elsif @payload[:id]
      find_conversation_by_message_id(@payload[:id])
    else
      log_conversation_not_found
      nil
    end
  end

  private

  def log_payload_debug_info
    Rails.logger.debug { "[AgentBot HTTP] Payload keys: #{@payload.keys}" }
    Rails.logger.debug { "[AgentBot HTTP] Payload conversation: #{@payload[:conversation]}" }
    Rails.logger.debug { "[AgentBot HTTP] Payload id: #{@payload[:id]}" }
  end

  def find_conversation_by_id(conversation_id)
    Rails.logger.info "[AgentBot HTTP] Found conversation ID in payload: #{conversation_id}"

    find_conversation_direct(conversation_id) ||
      find_conversation_scoped(conversation_id) ||
      find_conversation_via_message(conversation_id)
  end

  def find_conversation_direct(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    Rails.logger.info "[AgentBot HTTP] Direct find result: #{conversation.inspect}"
    conversation
  end

  def find_conversation_scoped(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    Rails.logger.info "[AgentBot HTTP] Scoped find result: #{conversation.inspect}"
    conversation
  end

  def find_conversation_via_message(_conversation_id)
    Rails.logger.warn "[AgentBot HTTP] Conversation not found, trying via message ID: #{@payload[:id]}"
    message = Message.find_by(id: @payload[:id])
    conversation = message&.conversation
    Rails.logger.info "[AgentBot HTTP] Conversation via message: #{conversation.inspect}"
    conversation
  end

  def find_conversation_by_message_id(message_id)
    Rails.logger.info "[AgentBot HTTP] Trying to find conversation via message ID: #{message_id}"
    message = Message.find_by(id: message_id)
    conversation = message&.conversation
    Rails.logger.info "[AgentBot HTTP] Found conversation via message: #{conversation.inspect}"
    conversation
  end

  def log_conversation_not_found
    Rails.logger.error '[AgentBot HTTP] Could not find conversation from payload'
    Rails.logger.error "[AgentBot HTTP] Full payload: #{@payload.inspect}"
  end
end
