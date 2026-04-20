class TestData::DisplayIdTracker
  attr_reader :current

  def initialize
    max_display_id = Conversation.maximum(:display_id) || 0
    @current = max_display_id
  end

  def next_id
    @current += 1
  end
end
