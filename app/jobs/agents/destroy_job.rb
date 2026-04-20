class Agents::DestroyJob < ApplicationJob
  queue_as :low

  def perform(_account, user)
    ActiveRecord::Base.transaction do
      destroy_notification_setting(user)
      remove_user_from_teams(user)
      remove_user_from_inboxes(user)
      unassign_conversations(user)
    end
  end

  private

  def remove_user_from_inboxes(user)
    user.inbox_members.destroy_all
  end

  def remove_user_from_teams(user)
    user.team_members.destroy_all
  end

  def destroy_notification_setting(user)
    user.notification_settings.destroy_all
  end

  def unassign_conversations(user)
    # rubocop:disable Rails/SkipsModelValidations
    user.assigned_conversations.in_batches.update_all(assignee_id: nil)
    # rubocop:enable Rails/SkipsModelValidations
  end
end
