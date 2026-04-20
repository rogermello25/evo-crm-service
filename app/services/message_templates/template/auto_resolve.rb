class MessageTemplates::Template::AutoResolve
  pattr_initialize [:conversation!]

  def perform
    message = auto_resolve_message
    return if message.blank?

    ActiveRecord::Base.transaction do
      conversation.messages.create!(auto_resolve_message_params(message))
    end
  end

  private

  delegate :contact, to: :conversation

  def auto_resolve_message
    GlobalConfigService.load('AUTO_RESOLVE_MESSAGE', nil)
  end

  def auto_resolve_message_params(message_content)
    {
      inbox_id: @conversation.inbox_id,
      message_type: :template,
      content: message_content
    }
  end
end
