class OauthApplicationPolicy < ApplicationPolicy
  def index?
    @user&.administrator? || @user&.has_permission?('oauth_applications.read')
  end

  def show?
    @user&.administrator? || @user&.has_permission?('oauth_applications.read')
  end

  def create?
    @user&.administrator? || @user&.has_permission?('oauth_applications.create')
  end

  def update?
    @user&.administrator? || @user&.has_permission?('oauth_applications.update')
  end

  def destroy?
    @user&.administrator? || @user&.has_permission?('oauth_applications.delete')
  end

  def regenerate_secret?
    @user&.administrator? || @user&.has_permission?('oauth_applications.update')
  end
end
