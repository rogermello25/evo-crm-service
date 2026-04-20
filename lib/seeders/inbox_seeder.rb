## Class to generate sample inboxes for a Evolution test installation.
############################################################
### Usage #####
#
#   # Seed inboxes
#   Seeders::InboxSeeder.new(company_data: {name: 'PaperLayer', domain: 'paperlayer.test'}).perform!
#
#
############################################################

class Seeders::InboxSeeder
  def initialize(company_data:)
    raise 'Inbox Seeding is not allowed in production.' unless ENV.fetch('ENABLE_ACCOUNT_SEEDING', !Rails.env.production?)

    @company_data = company_data
  end

  def perform!
    seed_website_inbox
    seed_facebook_inbox
    seed_twitter_inbox
    seed_whatsapp_inbox
    seed_sms_inbox
    seed_email_inbox
    seed_api_inbox
    seed_telegram_inbox
    seed_line_inbox
  end

  def seed_website_inbox
    channel = Channel::WebWidget.create!(website_url: "https://#{@company_data['domain']}")
    Inbox.create!(channel: channel, name: "#{@company_data['name']} Website")
  end

  def seed_facebook_inbox
    channel = Channel::FacebookPage.create!(user_access_token: SecureRandom.hex, page_access_token: SecureRandom.hex,
                                            page_id: SecureRandom.hex)
    Inbox.create!(channel: channel, name: "#{@company_data['name']} Facebook")
  end

  def seed_twitter_inbox
    channel = Channel::TwitterProfile.create!(twitter_access_token: SecureRandom.hex,
                                              twitter_access_token_secret: SecureRandom.hex, profile_id: '123')
    Inbox.create!(channel: channel, name: "#{@company_data['name']} Twitter")
  end

  def seed_whatsapp_inbox
    # rubocop:disable Rails/SkipsModelValidations
    Channel::Whatsapp.insert(
      {
        phone_number: Faker::PhoneNumber.cell_phone_in_e164,
        created_at: Time.now.utc,
        updated_at: Time.now.utc
      },
      returning: %w[id]
    )
    # rubocop:enable Rails/SkipsModelValidations

    channel = Channel::Whatsapp.last

    Inbox.create!(channel: channel, name: "#{@company_data['name']} Whatsapp")
  end

  def seed_sms_inbox
    channel = Channel::Sms.create!(phone_number: Faker::PhoneNumber.cell_phone_in_e164)
    Inbox.create!(channel: channel, name: "#{@company_data['name']} Mobile")
  end

  def seed_email_inbox
    channel = Channel::Email.create!(email: "test#{SecureRandom.hex}@#{@company_data['domain']}",
                                     forward_to_email: "test_fwd#{SecureRandom.hex}@#{@company_data['domain']}")
    Inbox.create!(channel: channel, name: "#{@company_data['name']} Email")
  end

  def seed_api_inbox
    channel = Channel::Api.create!
    Inbox.create!(channel: channel, name: "#{@company_data['name']} API")
  end

  def seed_telegram_inbox
    # rubocop:disable Rails/SkipsModelValidations
    bot_token = SecureRandom.hex
    Channel::Telegram.insert(
      {
        bot_name: (@company_data['name']).to_s,
        bot_token: bot_token,
        created_at: Time.now.utc,
        updated_at: Time.now.utc
      },
      returning: %w[id]
    )
    channel = Channel::Telegram.find_by(bot_token: bot_token)
    Inbox.create!(channel: channel, name: "#{@company_data['name']} Telegram")
    # rubocop:enable Rails/SkipsModelValidations
  end

  def seed_line_inbox
    channel = Channel::Line.create!(line_channel_id: SecureRandom.hex, line_channel_secret: SecureRandom.hex,
                                    line_channel_token: SecureRandom.hex)
    Inbox.create!(channel: channel, name: "#{@company_data['name']} Line")
  end
end
