class TeamMemberPolicy < ApplicationPolicy
  def index?
    # Administrators or users with team_members.read permission can list team members
    @user&.administrator? || @user&.has_permission?('team_members.read')
  end

  def show?
    # Administrators or users with team_members.read permission can view team members
    @user&.administrator? || @user&.has_permission?('team_members.read')
  end

  def create?
    @user&.administrator? || @user&.has_permission?('team_members.create')
  end

  def destroy?
    @user&.administrator? || @user&.has_permission?('team_members.delete')
  end

  def update?
    @user&.administrator? || @user&.has_permission?('team_members.update')
  end
end
