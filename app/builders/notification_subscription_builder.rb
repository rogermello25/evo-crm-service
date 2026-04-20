class NotificationSubscriptionBuilder
  pattr_initialize [:params, :user!]

  def perform
    Rails.logger.info("📱 [SUBSCRIPTION] Building subscription for user #{user.email}, type: #{params[:subscription_type]}, device_id: #{params[:subscription_attributes]&.dig(:device_id)}")

    # if multiple accounts were used to login in same browser
    move_subscription_to_user if identifier_subscription && identifier_subscription.user_id != user.id

    result = identifier_subscription.blank? ? build_identifier_subscription : update_identifier_subscription

    Rails.logger.info("📱 [SUBSCRIPTION] Subscription #{result.id} created/updated, type: #{result.subscription_type} (#{result.subscription_type_before_type_cast}), identifier: #{result.identifier}")

    result
  end

  private

  def identifier
    @identifier ||= params[:subscription_attributes][:endpoint] if params[:subscription_type] == 'browser_push'
    @identifier ||= params[:subscription_attributes][:device_id] if params[:subscription_type] == 'fcm'
    @identifier
  end

  def identifier_subscription
    @identifier_subscription ||= NotificationSubscription.find_by(identifier: identifier)
  end

  def move_subscription_to_user
    @identifier_subscription.update(user_id: user.id)
  end

  def build_identifier_subscription
    Rails.logger.info("📱 [SUBSCRIPTION] Creating new subscription with params: #{params.inspect}")
    @identifier_subscription = user.notification_subscriptions.create!(params.merge(identifier: identifier))
  end

  def update_identifier_subscription
    Rails.logger.info("📱 [SUBSCRIPTION] Updating existing subscription #{identifier_subscription.id} with params: #{params.inspect}")
    identifier_subscription.update(params.merge(identifier: identifier))
    identifier_subscription
  end
end
