class MessageTemplates::Template::OutOfOffice
  pattr_initialize [:conversation!]

  def perform
    ActiveRecord::Base.transaction do
      conversation.messages.create!(out_of_office_message_params)
    end
  rescue StandardError => e
    EvolutionExceptionTracker.new(e, account: nil).capture_exception
    true
  end

  private

  delegate :contact, to: :conversation
  delegate :inbox, to: :message

  def out_of_office_message_params
    content = @conversation.inbox&.out_of_office_message

    {
      inbox_id: @conversation.inbox_id,
      message_type: :template,
      content: content
    }
  end
end
