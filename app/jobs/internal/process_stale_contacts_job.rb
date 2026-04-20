# housekeeping
# remove stale contacts
# - have no identification (email, phone_number, and identifier are NULL)
# - have no conversations
# - are older than 30 days

class Internal::ProcessStaleContactsJob < ApplicationJob
  queue_as :housekeeping

  def perform
    Rails.logger.info "ProcessStaleContactsJob: Starting stale contacts cleanup"
    Internal::RemoveStaleContactsJob.perform_later
  end
end
