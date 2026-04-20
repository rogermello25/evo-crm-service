module BillingHelper
  private

  def default_plan?(_account = nil)
    installation_config = InstallationConfig.find_by(name: 'EVOLUTION_CLOUD_PLANS')
    default_plan = installation_config&.value&.first

    # Return false if no plans are configured, so that no checks are enforced
    return false if default_plan.blank?

    false
  end

  def conversations_this_month(_account = nil)
    Conversation.where('created_at > ?', 30.days.ago).count
  end

  def non_web_inboxes(_account = nil)
    Inbox.where.not(channel_type: Channel::WebWidget.to_s).count
  end

  def agents(_account = nil)
    User.count
  end
end
