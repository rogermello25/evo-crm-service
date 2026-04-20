# frozen_string_literal: true

class ScheduledActionTemplatePolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    user.present?
  end

  def update?
    record.created_by == user.id || user_admin?
  end

  def destroy?
    record.created_by == user.id || user_admin?
  end

  def apply?
    user.present?
  end

  private

  def user_admin?
    user.administrator?
  end
end
