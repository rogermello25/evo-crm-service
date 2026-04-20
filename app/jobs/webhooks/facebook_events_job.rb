class Webhooks::FacebookEventsJob < MutexApplicationJob
  queue_as :default
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  def perform(message)
    response = ::Integrations::Facebook::MessageParser.new(message)

    # Use message ID (source_id) for lock key if available, otherwise fallback to sender/recipient
    # This prevents duplicate processing of the same message when webhook is received multiple times
    lock_key = if response.identifier.present?
                 format(::Redis::Alfred::FACEBOOK_MESSAGE_MUTEX, sender_id: response.identifier, recipient_id: 'message')
               else
                 format(::Redis::Alfred::FACEBOOK_MESSAGE_MUTEX, sender_id: response.sender_id, recipient_id: response.recipient_id)
               end

    with_lock(lock_key) do
      process_message(response)
    end
  end

  def process_message(response)
    ::Integrations::Facebook::MessageCreator.new(response).perform
  end
end
