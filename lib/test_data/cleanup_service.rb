class TestData::CleanupService
  class << self
    def call
      Rails.logger.info 'Cleaning up any existing test data...'

      # Clean up test-generated data (messages, conversations, contacts, inboxes)
      # In single-tenant mode, we just clear the data directly
      Rails.logger.info 'Cleaning up test messages, conversations, contacts...'
      Message.where("source_id IS NOT NULL").delete_all
      Conversation.where("display_id > ?", 0).delete_all

      Rails.logger.info '==> Cleanup complete!'
    end
  end
end
