class MessageTemplates::Template::Greeting
  pattr_initialize [:conversation!]

  def perform
    ActiveRecord::Base.transaction do
      conversation.messages.create!(greeting_message_params)
    end
  rescue StandardError => e
    EvolutionExceptionTracker.new(e, account: nil).capture_exception
    true
  end

  private

  delegate :contact, to: :conversation
  delegate :inbox, to: :message

  def greeting_message_params
    content = @conversation.inbox&.greeting_message

    {
      inbox_id: @conversation.inbox_id,
      message_type: :template,
      content: content
    }
  end
end
