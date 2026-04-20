# frozen_string_literal: true

class ScheduledActionPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    @user.administrator? || @user.agent?
  end

  def update?
    @user.administrator? || @user.agent?
  end

  def destroy?
    @user.administrator? || @user.agent?
  end
end

