# Background job to process moderation for Facebook comments
# Runs asynchronously to avoid blocking the main listener
class Facebook::Moderation::ProcessJob < ApplicationJob
  queue_as :default

  def perform(message_id, conversation_id, agent_bot_inbox_id)
    message = Message.find(message_id)
    conversation = Conversation.find(conversation_id)
    agent_bot_inbox = AgentBotInbox.find(agent_bot_inbox_id)

    processor = Facebook::Moderation::ProcessorService.new(
      message: message,
      conversation: conversation,
      agent_bot_inbox: agent_bot_inbox
    )

    processor.process
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[Facebook Moderation] Record not found: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "[Facebook Moderation] Error processing moderation: #{e.message}"
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end
end

