# frozen_string_literal: true

# FacebookCommentModerationSerializer - Optimized serialization for FacebookCommentModeration resources
#
# Plain Ruby module for Oj direct serialization
#
# Usage:
#   FacebookCommentModerationSerializer.serialize(@moderation)
#
module FacebookCommentModerationSerializer
  extend self

  # Serialize single FacebookCommentModeration
  #
  # @param moderation [FacebookCommentModeration] Moderation to serialize
  # @param options [Hash] Serialization options
  #
  # @return [Hash] Serialized moderation ready for Oj
  #
  def serialize(moderation)
    result = {
      id: moderation.id.to_s,
      comment_id: moderation.comment_id,
      conversation_id: moderation.conversation_id.to_s,
      message_id: moderation.message_id.to_s,
      moderation_type: moderation.moderation_type,
      status: moderation.status,
      action_type: moderation.action_type,
      response_content: moderation.response_content,
      rejection_reason: moderation.rejection_reason,
      sentiment_offensive: moderation.sentiment_offensive,
      sentiment_confidence: moderation.sentiment_confidence,
      sentiment_reason: moderation.sentiment_reason,
      moderated_by_id: moderation.moderated_by_id&.to_s,
      moderated_at: moderation.moderated_at&.iso8601,
      created_at: moderation.created_at&.iso8601,
      updated_at: moderation.updated_at&.iso8601
    }

    if moderation.message.present?
      result[:message] = {
        id: moderation.message.id.to_s,
        content: moderation.message.content,
        created_at: moderation.message.created_at&.iso8601
      }
    end

    if moderation.conversation.present?
      result[:conversation] = {
        id: moderation.conversation.id.to_s,
        display_id: moderation.conversation.display_id
      }
    end

    if moderation.moderated_by.present?
      result[:moderated_by] = {
        id: moderation.moderated_by.id.to_s,
        name: moderation.moderated_by.name,
        email: moderation.moderated_by.email
      }
    end

    result
  end

  # Serialize collection of FacebookCommentModerations
  #
  # @param moderations [Array<FacebookCommentModeration>, ActiveRecord::Relation]
  #
  # @return [Array<Hash>] Array of serialized moderations
  #
  def serialize_collection(moderations)
    return [] unless moderations
    
    moderations.map { |moderation| serialize(moderation) }
  end
end

