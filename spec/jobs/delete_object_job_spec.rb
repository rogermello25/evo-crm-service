# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeleteObjectJob, type: :job do
  describe '#perform' do
    it 'deletes inbox conversations and their messages while preserving other inbox data' do
      contact = Contact.create!(name: 'Cascade Contact', email: 'cascade-contact@example.com')

      inbox = Inbox.create!(name: 'Inbox To Delete')
      inbox_contact_inbox = ContactInbox.create!(inbox: inbox, contact: contact)
      inbox_conversation = Conversation.create!(
        inbox: inbox,
        contact: contact,
        contact_inbox: inbox_contact_inbox
      )
      inbox_message = Message.create!(
        inbox: inbox,
        conversation: inbox_conversation,
        message_type: :incoming,
        content: 'Message in deletable inbox'
      )

      other_inbox = Inbox.create!(name: 'Inbox To Keep')
      other_contact_inbox = ContactInbox.create!(inbox: other_inbox, contact: contact)
      other_conversation = Conversation.create!(
        inbox: other_inbox,
        contact: contact,
        contact_inbox: other_contact_inbox
      )
      other_message = Message.create!(
        inbox: other_inbox,
        conversation: other_conversation,
        message_type: :incoming,
        content: 'Message in preserved inbox'
      )

      described_class.perform_now(inbox)

      expect(Inbox.exists?(inbox.id)).to be(false)
      expect(Conversation.exists?(inbox_conversation.id)).to be(false)
      expect(Message.exists?(inbox_message.id)).to be(false)

      expect(Inbox.exists?(other_inbox.id)).to be(true)
      expect(Conversation.exists?(other_conversation.id)).to be(true)
      expect(Message.exists?(other_message.id)).to be(true)
    end
  end
end
