class Messages::StatusUpdateService
  attr_reader :message, :status, :external_error

  def initialize(message, status, external_error = nil)
    @message = message
    @status = status
    @external_error = external_error
  end

  def perform
    return false unless valid_status_transition?

    update_message_status
  end

  private

  def update_message_status
    # Update status and set external_error in content_attributes when failed
    attrs = { status: status }
    if status == 'failed' && external_error.present?
      attrs[:content_attributes] = (message.content_attributes || {}).merge(external_error: external_error)
    end
    message.update!(attrs)
  end

  def valid_status_transition?
    return false unless Message.statuses.key?(status)

    # Don't allow changing from 'read' to 'delivered'
    return false if message.read? && status == 'delivered'

    true
  end
end
