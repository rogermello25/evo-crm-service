# frozen_string_literal: true

module CsatSurveyResponseSerializer
  extend self

  def serialize(response, **options)
    return nil unless response

    data = {
      id: response.id,
      conversation_id: response.conversation_id,
      message_id: response.message_id,
      contact_id: response.contact_id,
      assigned_agent_id: response.assigned_agent_id,
      rating: response.rating,
      feedback_message: response.feedback_message,
      created_at: response.created_at&.iso8601,
      updated_at: response.updated_at&.iso8601
    }

    if options[:include_conversation] && response.conversation
      data[:conversation] = ConversationSerializer.serialize(response.conversation, include_messages: false)
    end

    if options[:include_contact] && response.contact
      data[:contact] = ContactSerializer.serialize(response.contact)
    end

    if options[:include_assigned_agent] && response.assigned_agent
      data[:assigned_agent] = UserSerializer.serialize(response.assigned_agent)
    end

    data
  end

  def serialize_collection(responses, **options)
    return [] unless responses

    responses.map { |response| serialize(response, **options) }
  end
end
