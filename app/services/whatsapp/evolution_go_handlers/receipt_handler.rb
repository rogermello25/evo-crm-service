module Whatsapp::EvolutionGoHandlers::ReceiptHandler
  include Whatsapp::EvolutionGoHandlers::Helpers

  private

  def process_read_receipt
    Rails.logger.info 'Evolution Go API: Processing Receipt event'

    receipt_data = processed_params[:data]
    return if receipt_data.blank?

    event_state = processed_params[:state]
    return if event_state.blank?

    Rails.logger.info "Evolution Go API: Receipt state: #{event_state}"
    Rails.logger.debug { "Evolution Go API: Receipt data: #{receipt_data.inspect}" }

    # Extract message IDs and status
    message_ids = receipt_data[:MessageIDs]
    return if message_ids.blank?

    Rails.logger.info "Evolution Go API: Processing receipt for #{message_ids.size} message(s)"

    # Map Evolution Go receipt state to Evolution status
    status = map_receipt_state_to_status(event_state, receipt_data[:Type])
    return unless status

    # Process receipts efficiently based on count
    if message_ids.size > 10
      process_bulk_receipts(message_ids, status, receipt_data)
    else
      message_ids.each do |message_id|
        process_single_receipt(message_id, status, receipt_data)
      end
    end
  end

  def process_bulk_receipts(message_ids, status, _receipt_data)
    # Efficient bulk processing for large receipt batches
    Rails.logger.info "Evolution Go API: Processing bulk receipt for #{message_ids.size} messages"

    # Find all messages at once
    messages = inbox.messages.where(source_id: message_ids)
    found_ids = messages.pluck(:source_id)
    missing_ids = message_ids - found_ids

    if missing_ids.any?
      Rails.logger.warn "Evolution Go API: Missing messages for receipt: #{missing_ids.first(5).join(', ')}#{missing_ids.size > 5 ? " and #{missing_ids.size - 5} more" : ''}"
    end

    # Bulk update messages that can be updated
    updatable_messages = messages.select { |msg| can_update_message_status?(msg, status) }
    if updatable_messages.any?
      Message.where(id: updatable_messages.map(&:id)).update_all(status: status)
      updatable_messages.each do |message|
        Rails.logger.debug { "Evolution Go API: Bulk updated message #{message.source_id} to #{status}" }
      end
    end

    # Update contact activity for outgoing messages
    outgoing_messages = messages.outgoing
    return unless outgoing_messages.any?

    contacts = Contact.joins(:contact_inboxes)
                      .where(conversations: { id: outgoing_messages.select(:conversation_id).distinct })
                      .distinct

    contacts.update_all(last_activity_at: Time.current)
  end

  def update_contact_activity_for_bulk_receipts(messages, status, receipt_data)
    return unless status == 'read'
    return if receipt_data[:IsFromMe] == true

    # Find contacts that need activity update (outgoing messages that were read)
    outgoing_messages = messages.where(message_type: 'outgoing')
    return if outgoing_messages.empty?

    # Update contacts' last activity
    contacts = Contact.joins(:conversations)
                      .where(conversations: { id: outgoing_messages.select(:conversation_id).distinct })
                      .distinct

    contacts.update_all(last_activity_at: Time.current)
    Rails.logger.info "Evolution Go API: Updated last activity for #{contacts.count} contacts from bulk receipt"
  end

  def process_single_receipt(message_id, status, _receipt_data)
    message = find_message_by_source_id_for_receipt(message_id, _receipt_data)
    return unless message && can_update_message_status?(message, status)

    # Update message status
    message.update!(status: status)
    Rails.logger.debug { "Evolution Go API: Updated message #{message.source_id} to #{status}" }
  end

  def find_message_by_source_id_for_receipt(message_id, _receipt_data)
    message = inbox.messages.find_by(source_id: message_id)

    if message
      Rails.logger.debug do
        "Evolution Go API: Found message: #{message.id}, current status: #{message.status}, message_type: #{message.message_type}"
      end
    else
      Rails.logger.debug { "Evolution Go API: Message not found in inbox #{inbox.id} with source_id: #{message_id}" }
    end

    message
  end

  def update_message_status_from_receipt(message, status, message_id)
    # Check if status transition is valid
    unless valid_receipt_status_transition?(message.status, status)
      Rails.logger.warn "Evolution Go API: Invalid status transition for message #{message_id}: #{message.status} -> #{status}"
      return
    end

    # Update the message status
    if message.update(status: status)
      Rails.logger.info "Evolution Go API: Updated message #{message_id} status to #{status}"
    else
      Rails.logger.error "Evolution Go API: Failed to update message #{message_id}: #{message.errors.full_messages.join(', ')}"
    end
  end

  def update_contact_activity_if_needed(message, status, receipt_data)
    # Update contact's last activity when they read our message (incoming receipt)
    return unless status == 'read'
    return unless message.message_type == 'outgoing'  # Our message was read by contact
    return if receipt_data[:IsFromMe] == true  # Skip if receipt is from us

    contact = message.conversation&.contact
    return unless contact

    # Update contact's last activity timestamp
    contact.update!(last_activity_at: Time.current)
    Rails.logger.info "Evolution Go API: Updated contact #{contact.id} last activity for read receipt"
  end

  def can_update_message_status?(message, new_status)
    # Define valid status transitions to prevent invalid updates
    current_status = message.status

    case current_status
    when 'sent'
      %w[delivered read failed].include?(new_status)
    when 'delivered'
      %w[read].include?(new_status)
    when 'read'
      false # Read is final status
    when 'failed'
      false # Failed is final status
    else
      true # Allow any transition from unknown/nil status
    end
  end

  def map_receipt_state_to_status(state, _type)
    case state.downcase
    when 'read'
      'read'
    when 'delivered'
      'delivered'
    else
      Rails.logger.warn "Evolution Go API: Unknown receipt state: #{state}"
      nil
    end
  end

  def valid_receipt_status_transition?(current_status, new_status)
    # Define valid status transitions for receipts
    # Similar to other handlers but specific to receipt events
    valid_transitions = {
      'sent' => %w[delivered read],
      'delivered' => %w[read],
      'read' => [],  # Read is final status
      'failed' => [] # Failed is final status
    }

    # Allow transition if current status is blank/nil
    return true if current_status.blank?

    allowed_transitions = valid_transitions[current_status] || []
    allowed_transitions.include?(new_status)
  end
end
