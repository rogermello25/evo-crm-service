class RemoveOldTemplateColumns < ActiveRecord::Migration[7.1]
  def up
    remove_column :channel_whatsapp, :message_templates, :jsonb
    remove_column :channel_whatsapp, :message_templates_last_updated, :datetime
    
    remove_column :channel_facebook_pages, :message_templates, :jsonb
    remove_column :channel_facebook_pages, :message_templates_last_updated, :datetime
    
    remove_column :channel_instagram, :message_templates, :jsonb
    remove_column :channel_instagram, :message_templates_last_updated, :datetime
    
    remove_column :channel_line, :message_templates, :jsonb
    remove_column :channel_line, :message_templates_last_updated, :datetime
    
    remove_column :channel_telegram, :message_templates, :jsonb
    remove_column :channel_telegram, :message_templates_last_updated, :datetime
    
    remove_column :channel_twilio_sms, :message_templates, :jsonb
    remove_column :channel_twilio_sms, :message_templates_last_updated, :datetime
  end

  def down
    add_column :channel_whatsapp, :message_templates, :jsonb, default: {}
    add_column :channel_whatsapp, :message_templates_last_updated, :datetime
    
    add_column :channel_facebook_pages, :message_templates, :jsonb, default: []
    add_column :channel_facebook_pages, :message_templates_last_updated, :datetime
    
    add_column :channel_instagram, :message_templates, :jsonb, default: []
    add_column :channel_instagram, :message_templates_last_updated, :datetime
    
    add_column :channel_line, :message_templates, :jsonb, default: []
    add_column :channel_line, :message_templates_last_updated, :datetime
    
    add_column :channel_telegram, :message_templates, :jsonb, default: []
    add_column :channel_telegram, :message_templates_last_updated, :datetime
    
    add_column :channel_twilio_sms, :message_templates, :jsonb, default: []
    add_column :channel_twilio_sms, :message_templates_last_updated, :datetime
  end
end
