class Api::V1::Widget::ConversationsController < Api::V1::Widget::BaseController
  include Events::Types
  before_action :render_not_found_if_empty, only: [:toggle_typing, :toggle_status, :set_custom_attributes, :destroy_custom_attributes]

  def index
    @conversation = conversation
  end

  def create
    # Validate pre-chat form data if enabled
    validate_pre_chat_form!

    ActiveRecord::Base.transaction do
      process_update_contact
      @conversation = create_conversation
      conversation.messages.create!(message_params)
      # TODO: Temporary fix for message type cast issue, since message_type is returning as string instead of integer
      conversation.reload
    end
  rescue Widget::PreChatFormValidator::ValidationError => e
    render json: {
      error: 'Validation failed',
      errors: e.errors,
      code: 'PRE_CHAT_VALIDATION_ERROR'
    }, status: :unprocessable_entity
  end

  def process_update_contact
    # Use sanitized data if available, otherwise use original params
    contact_data = if @sanitized_contact_params
                     {
                       email: @sanitized_contact_params[:email] || @sanitized_contact_params['email'],
                       phone_number: @sanitized_contact_params[:phone_number] || @sanitized_contact_params['phone_number'],
                       name: @sanitized_contact_params[:name] || @sanitized_contact_params['name']
                     }
                   else
                     { email: contact_email, phone_number: contact_phone_number, name: contact_name }
                   end

    @contact = ContactIdentifyAction.new(
      contact: @contact,
      params: contact_data,
      retain_original_contact_name: true,
      discard_invalid_attrs: true
    ).perform
  end

  def update_last_seen
    head :ok && return if conversation.nil?

    conversation.contact_last_seen_at = DateTime.now.utc
    conversation.save!
    ::Conversations::UpdateMessageStatusJob.perform_later(conversation.id, conversation.contact_last_seen_at)
    head :ok
  end

  def transcript
    if conversation.present? && conversation.contact.present? && conversation.contact.email.present?
      ConversationReplyMailer.with(account: nil).conversation_transcript(
        conversation,
        conversation.contact.email
      )&.deliver_later
    end
    head :ok
  end

  def toggle_typing
    case permitted_params[:typing_status]
    when 'on'
      trigger_typing_event(CONVERSATION_TYPING_ON)
    when 'recording'
      trigger_typing_event(CONVERSATION_RECORDING)
    when 'off'
      trigger_typing_event(CONVERSATION_TYPING_OFF)
    end

    head :ok
  end

  def toggle_status
    requested_status = permitted_params[:status].presence&.to_sym
    return head :forbidden unless @web_widget.end_conversation? || requested_status == :resolved

    # NOTE: Current.contact is used by Conversation callbacks (after_update_commit) to attribute the activity message.
    # Keep it set for the whole request and clear it at the end to avoid leaking across requests.
    Current.contact = @contact
    old_status = conversation.status
    new_status =
      if requested_status.present?
        requested_status
      else
        conversation.resolved? ? :open : :resolved
      end

    ActiveRecord::Base.transaction do
      conversation.update!(status: new_status)
    end

    # Reload to ensure we have the latest data including any callbacks that may have run
    conversation.reload

    # The event CONVERSATION_STATUS_CHANGED is automatically dispatched by the Conversation model's
    # after_update_commit callback (notify_status_change). The ActionCableListener will broadcast
    # this event to the contact_inbox pubsub_token, which the widget frontend listens to.

    render json: {
      success: true,
      message: "Conversation status changed from #{old_status} to #{new_status}",
      conversation: {
        id: conversation.display_id,
        uuid: conversation.uuid,
        inbox_id: conversation.inbox_id,
        status: conversation.status,
        status_changed: true,
        old_status: old_status,
        new_status: new_status.to_s,
        contact_last_seen_at: conversation.contact_last_seen_at&.to_i,
        updated_at: conversation.updated_at.to_i
      }
    }
  ensure
    Current.contact = nil
  end

  def set_custom_attributes
    conversation.update!(custom_attributes: permitted_params[:custom_attributes])
  end

  def destroy_custom_attributes
    conversation.custom_attributes = conversation.custom_attributes.excluding(params[:custom_attribute])
    conversation.save!
    render json: conversation
  end

  private

  def validate_pre_chat_form!
    return unless @web_widget.pre_chat_form_enabled?

    validator = Widget::PreChatFormValidator.new(
      web_widget: @web_widget,
      contact_params: {
        name: contact_name,
        email: contact_email,
        phone_number: contact_phone_number
      },
      message_content: permitted_params.dig(:message, :content),
      custom_attributes: permitted_params[:custom_attributes] || {}
    )

    result = validator.perform
    
    # Update params with sanitized data
    if result[:sanitized_data]
      sanitized = result[:sanitized_data]
      @sanitized_contact_params = sanitized[:contact_params]
      @sanitized_message_content = sanitized[:message_content]
      @sanitized_custom_attributes = sanitized[:custom_attributes]
    end
  end

  def trigger_typing_event(event)
    Rails.configuration.dispatcher.dispatch(event, Time.zone.now, conversation: conversation, user: @contact)
  end

  def render_not_found_if_empty
    head :not_found if conversation.nil?
  end

  def permitted_params
    params.permit(:id, :typing_status, :website_token, :email, :status, contact: [:name, :email, :phone_number],
                                                               message: [:content, :referer_url, :timestamp, :echo_id],
                                                               custom_attributes: {})
  end
end
