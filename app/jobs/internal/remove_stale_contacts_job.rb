# housekeeping
# remove contacts that:
# - have no identification (email, phone_number, and identifier are NULL)
# - have no conversations
# - are older than 30 days

class Internal::RemoveStaleContactsJob < ApplicationJob
  queue_as :housekeeping

  def perform(_account = nil, batch_size = 1000)
    Internal::RemoveStaleContactsService.new.perform(batch_size)
  end
end
