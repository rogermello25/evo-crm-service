class AddDisplayNameToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :display_name, :string
  end
end

