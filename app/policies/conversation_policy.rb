class ConversationPolicy < ApplicationPolicy
  def index?
    # Administrators or users with conversations.read permission can list conversations
    @user&.administrator? || @user&.has_permission?('conversations.read')
  end

  def show?
    # Administrators or users with conversations.read permission can view conversations
    @user&.administrator? || @user&.has_permission?('conversations.read')
  end

  def destroy?
    @user&.administrator? || @user&.has_permission?('conversations.delete')
  end
end
