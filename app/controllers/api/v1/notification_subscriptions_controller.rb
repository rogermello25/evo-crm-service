class Api::V1::NotificationSubscriptionsController < Api::BaseController
  before_action :set_user

  def create
    Rails.logger.info("📱 [SUBSCRIPTION API] Creating subscription for user #{@user.email}")
    Rails.logger.info("📱 [SUBSCRIPTION API] Raw params: #{params.inspect}")
    Rails.logger.info("📱 [SUBSCRIPTION API] Permitted params: #{notification_subscription_params.inspect}")

    notification_subscription = NotificationSubscriptionBuilder.new(user: @user, params: notification_subscription_params).perform

    Rails.logger.info("📱 [SUBSCRIPTION API] Subscription created successfully: #{notification_subscription.id}, type: #{notification_subscription.subscription_type}")

    render json: notification_subscription
  end

  def destroy
    notification_subscription = NotificationSubscription.where(["subscription_attributes->>'push_token' = ?", params[:push_token]]).first
    notification_subscription.destroy! if notification_subscription.present?
    head :ok
  end

  private

  def set_user
    @user = current_user
  end

  def notification_subscription_params
    params.require(:notification_subscription).permit(:subscription_type, subscription_attributes: {})
  end
end
