# frozen_string_literal: true

# Service to update a comment message from Facebook feed webhook
class Integrations::Facebook::CommentUpdater
  attr_reader :parser, :page_id

  def initialize(parser, page_id: nil)
    @parser = parser
    @page_id = page_id
  end

  def perform
    return unless parser.comment_event?
    return unless parser.edited_event?

    channel = find_channel_by_page_id
    return unless channel

    inbox = channel.inbox
    return unless inbox

    # Find conversation for this post
    conversation = find_conversation_for_post(inbox)
    return unless conversation

    # Find and update message
    message = conversation.messages.find_by(source_id: parser.comment_id)
    return unless message

    message.update!(
      content: parser.message,
      content_attributes: message.content_attributes.merge(
        post_id: parser.post_id,
        comment_id: parser.comment_id,
        is_boosted_post: parser.is_boosted?
      )
    )
  end

  private

  def find_channel_by_page_id
    return nil unless page_id

    Channel::FacebookPage.find_by(page_id: page_id)
  end

  def find_conversation_for_post(inbox)
    contact_inbox = inbox.contact_inboxes.find_by(source_id: parser.post_id)
    return nil unless contact_inbox

    Conversation.joins(:contact_inbox)
                .where(contact_inboxes: { id: contact_inbox.id })
                .where("additional_attributes->>'conversation_type' = ?", 'post')
                .where("additional_attributes->>'post_id' = ?", parser.post_id)
                .first
  end
end

