# frozen_string_literal: true

# Service to remove a comment message from Facebook feed webhook
class Integrations::Facebook::CommentRemover
  attr_reader :parser, :page_id

  def initialize(parser, page_id: nil)
    @parser = parser
    @page_id = page_id
  end

  def perform
    return unless parser.comment_event?
    return unless parser.remove_event?

    channel = find_channel_by_page_id
    return unless channel

    inbox = channel.inbox
    return unless inbox

    # Find conversation for this post
    conversation = find_conversation_for_post(inbox)
    return unless conversation

    # Find and delete message from system
    message = conversation.messages.find_by(source_id: parser.comment_id)
    return unless message

    Rails.logger.info "[Facebook CommentRemover] Deleting message #{message.id} (comment_id: #{parser.comment_id}) from conversation #{conversation.id}"

    # First, find and delete all reply messages (responses to this comment)
    delete_reply_messages(parser.comment_id, conversation)

    # Delete any associated moderation records first to avoid foreign key violations
    FacebookCommentModeration.where(message: message).destroy_all

    # Delete the message from the system
    message.destroy

    Rails.logger.info "[Facebook CommentRemover] Successfully deleted message #{message.id} from system"
  end

  private

  def find_channel_by_page_id
    return nil unless page_id

    Channel::FacebookPage.find_by(page_id: page_id)
  end

  def find_conversation_for_post(inbox)
    # Find conversation by post_id in additional_attributes
    # All conversations for the same post share the same post_id
    Conversation.where(inbox_id: inbox.id)
                .where("additional_attributes->>'conversation_type' = ?", 'post')
                .where("additional_attributes->>'post_id' = ?", parser.post_id)
                .first
  end

  # Delete all reply messages (responses) to a comment
  # This recursively deletes all nested replies
  def delete_reply_messages(comment_id, conversation)
    return unless comment_id.present?
    return unless conversation.present?

    Rails.logger.info "[Facebook CommentRemover] Finding reply messages for comment #{comment_id}"

    # Find all messages that are replies to this comment
    # Replies have in_reply_to_external_id matching the comment_id
    reply_messages = conversation.messages.where(
      "content_attributes->>'in_reply_to_external_id' = ?",
      comment_id.to_s
    )

    Rails.logger.info "[Facebook CommentRemover] Found #{reply_messages.count} reply messages for comment #{comment_id}"

    reply_messages.find_each do |reply_message|
      Rails.logger.info "[Facebook CommentRemover] Processing reply message #{reply_message.id} (source_id: #{reply_message.source_id})"

      # Recursively delete replies to this reply (nested replies)
      if reply_message.source_id.present?
        delete_reply_messages(reply_message.source_id, conversation)
      end

      # Delete moderation records for this reply
      FacebookCommentModeration.where(message: reply_message).destroy_all

      # Delete the reply message from the system
      Rails.logger.info "[Facebook CommentRemover] Deleting reply message #{reply_message.id} from system"
      begin
        reply_message.destroy
        Rails.logger.info "[Facebook CommentRemover] Reply message #{reply_message.id} deleted successfully from system"
      rescue StandardError => e
        Rails.logger.error "[Facebook CommentRemover] Error deleting reply message #{reply_message.id}: #{e.message}"
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end
  end
end

