class PipelineTaskPolicy < ApplicationPolicy
  def index?
    @user.administrator? || @user.agent?
  end

  def show?
    return true if @user.administrator?

    # Agents can see tasks
    @user.agent?
  end

  def create?
    @user.administrator? || @user.agent?
  end

  def update?
    return true if @user.administrator?

    # Creator or assignee can update
    @record.created_by_id == @user.id || @record.assigned_to_id == @user.id
  end

  def destroy?
    return true if @user.administrator?

    # Only creator can delete
    @record.created_by_id == @user.id
  end

  def complete?
    update?
  end

  def cancel?
    update?
  end

  def reopen?
    update?
  end

  def add_subtask?
    # Can add subtask if can create tasks and can update parent task
    create? && update?
  end

  def move?
    # Can move if can update the task
    update?
  end

  def reorder?
    # Can reorder if can update the task
    update?
  end

  def statistics?
    index?
  end
end
