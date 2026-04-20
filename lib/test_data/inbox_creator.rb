class TestData::InboxCreator
  def self.create_all
    Array.new(TestData::Constants::INBOXES_PER_ACCOUNT) do
      channel = Channel::Api.create!
      Inbox.create!(
        name: "API Inbox #{SecureRandom.hex(4)}",
        channel: channel
      )
    end
  end
end
