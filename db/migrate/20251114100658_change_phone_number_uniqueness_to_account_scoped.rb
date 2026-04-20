class ChangePhoneNumberUniquenessToAccountScoped < ActiveRecord::Migration[7.1]
  # This migration is now a no-op. The phone_number uniqueness index
  # on channel_whatsapp is global (not account-scoped) in single-tenant mode.
  def up
    # no-op: phone_number already has a global unique index
  end

  def down
    # no-op
  end
end
