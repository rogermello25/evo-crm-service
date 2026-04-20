class Google::CallbacksController < OauthCallbackController
  include GoogleConcern

  def find_channel_by_email
    Channel::Email.find_by(email: users_data['email'], account: account)
  end

  def update_channel(channel_email)
    # Merge provider_config to preserve existing settings like push_enabled and watch_history_id
    existing_config = channel_email.provider_config || {}
    merged_config = existing_config.merge(
      'access_token' => parsed_body['access_token'],
      'refresh_token' => parsed_body['refresh_token'],
      'expires_on' => (Time.current.utc + 1.hour).to_s
    )
    channel_email.update!(
      provider: provider_name,
      provider_config: merged_config
    )
  end

  def after_channel_update(channel_email)
    # Enable push notifications automatically for Gmail
    return unless channel_email.google?

    # Enable push in background to avoid blocking the callback
    begin
      channel_email.enable_push!
      Rails.logger.info "[GMAIL_PUSH] Push enabled automatically for #{channel_email.email}"
    rescue StandardError => e
      Rails.logger.error "[GMAIL_PUSH] Failed to enable push for #{channel_email.email}: #{e.message}"
      EvolutionExceptionTracker.new(e, account: nil).capture_exception
    end
  end

  private

  def provider_name
    'google'
  end

  def oauth_client
    # from GoogleConcern
    google_client
  end
end
