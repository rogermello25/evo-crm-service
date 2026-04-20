# frozen_string_literal: true

# Service to create a comment message from Facebook feed webhook
class Integrations::Facebook::CommentCreator
  attr_reader :parser, :page_id

  def initialize(parser, page_id: nil)
    @parser = parser
    @page_id = page_id
  end

  def perform
    return unless parser.comment_event?
    return unless parser.add_event?

    # Find Facebook page channel by page_id
    channel = find_channel_by_page_id

    return unless channel

    inbox = channel.inbox
    return unless inbox

    # Skip comments from the page itself (to prevent processing our own messages)
    if parser.from_id.present? && channel.page_id.present? && parser.from_id.to_s == channel.page_id.to_s
      Rails.logger.info("[Facebook CommentCreator] Skipping comment from page itself (from_id: #{parser.from_id}, page_id: #{channel.page_id}, comment_id: #{parser.comment_id})")
      return
    end

    # First, create or find contact for the comment author
    # This needs to happen before creating the conversation
    contact_inbox = create_commenter_contact_inbox(inbox)

    # Get or create conversation for this post (using the commenter's contact)
    conversation = Facebook::PostConversationService.new(
      inbox: inbox,
      post_id: parser.post_id,
      is_boosted: parser.is_boosted?,
      contact_inbox: contact_inbox
    ).perform

    return unless conversation

    # Check if message already exists (prevent duplicates)
    # This checks both incoming and outgoing messages to catch messages we sent
    if message_exists?(conversation)
      Rails.logger.info("[Facebook CommentCreator] Message already exists (comment_id: #{parser.comment_id}), skipping creation")
      return
    end

    # Create message from comment
    Messages::Facebook::CommentBuilder.new(parser, inbox, conversation).perform
  end

  private

  def find_channel_by_page_id
    return nil unless page_id

    Channel::FacebookPage.find_by(page_id: page_id)
  end

  def message_exists?(conversation)
    # Check if message exists by source_id (works for both incoming and outgoing messages)
    # When we send a message, it gets a source_id when Facebook returns the comment ID
    # So we need to check all messages, not just incoming ones
    exists = conversation.messages.exists?(source_id: parser.comment_id)

    if exists
      existing_message = conversation.messages.find_by(source_id: parser.comment_id)
      Rails.logger.info("[Facebook CommentCreator] Found existing message: id=#{existing_message.id}, message_type=#{existing_message.message_type}, sender_type=#{existing_message.sender_type}, source_id=#{existing_message.source_id}")
    end

    exists
  end

  def create_commenter_contact_inbox(inbox)
    # Create or find contact for the comment author
    contact_params = {
      name: parser.from_name || "Facebook User #{parser.from_id[0..10]}",
      additional_attributes: {
        facebook_user_id: parser.from_id
      }
    }

    ::ContactInboxWithContactBuilder.new(
      source_id: parser.from_id,
      inbox: inbox,
      contact_attributes: contact_params
    ).perform
  end
end

