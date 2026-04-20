class ReportPolicy < ApplicationPolicy
  def view?
    @user.administrator?
  end
end

ReportPolicy.prepend_mod_with('ReportPolicy')
