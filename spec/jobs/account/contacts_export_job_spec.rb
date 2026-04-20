# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Account::ContactsExportJob, type: :job do
  let!(:user) { User.create!(name: 'Export Test User', email: "export-test-#{SecureRandom.hex(4)}@example.com") }

  describe '#perform' do
    it 'generates CSV and sends mail' do
      mailer_instance = instance_double(AdministratorNotifications::AccountNotificationMailer)
      mail_message = instance_double(ActionMailer::MessageDelivery)

      allow(AdministratorNotifications::AccountNotificationMailer)
        .to receive(:with).with({}).and_return(mailer_instance)
      allow(mailer_instance)
        .to receive(:contact_export_complete_with_data).and_return(mail_message)
      allow(mail_message).to receive(:deliver_later)

      described_class.perform_now(nil, user.id, %w[id name email], {})

      expect(mailer_instance).to have_received(:contact_export_complete_with_data) do |csv_data, email|
        expect(csv_data).to include('id,name,email')
        expect(email).to eq(user.email)
      end
    end
  end
end
