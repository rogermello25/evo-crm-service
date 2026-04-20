class Account::ContactsExportJob < ApplicationJob
  queue_as :low

  def perform(user_id, column_names, params)
    @params = params
    @user = User.find(user_id)

    headers = valid_headers(column_names)
    csv_data = generate_csv(headers)
    send_mail_with_attachment(csv_data)
  end

  private

  def generate_csv(headers)
    CSV.generate do |csv|
      csv << headers
      contacts.each do |contact|
        csv << headers.map { |header| contact.send(header) }
      end
    end
  end

  def contacts
    if @params.present? && @params[:payload].present? && @params[:payload].any?
      result = ::Contacts::FilterService.new(nil, @user, @params).perform
      result[:contacts]
    elsif @params[:label].present?
      Contact.resolved_contacts.tagged_with(@params[:label], any: true)
    else
      Contact.resolved_contacts
    end
  end

  def valid_headers(column_names)
    (column_names.presence || default_columns) & Contact.column_names
  end

  def send_mail_with_attachment(csv_data)
    return if csv_data.blank?

    mailer = AdministratorNotifications::AccountNotificationMailer.with({})
    mailer.contact_export_complete_with_data(csv_data, @user.email)&.deliver_later
  end

  def default_columns
    %w[id name email phone_number]
  end
end
