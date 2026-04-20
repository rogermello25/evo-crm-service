# frozen_string_literal: true

# Register ContactCompanyListener for Wisper events
Rails.application.config.after_initialize do
  # Register the contact company listener globally to catch all events
  contact_company_listener = ContactCompanyListener.instance
  Wisper.subscribe(contact_company_listener)

  Rails.logger.info 'ContactCompanyListener registered successfully'
end

