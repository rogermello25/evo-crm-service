###############
# One library to capture_exception and send to the specific service.
# # e as exception, u for user
# Usage: EvolutionExceptionTracker(e, user: u).capture_exception
############

class EvolutionExceptionTracker
  def initialize(exception, user: nil, account: nil)
    @exception = exception
    @user = user
  end

  def capture_exception
    capture_exception_with_sentry if ENV['SENTRY_DSN'].present?
    Rails.logger.error @exception
  end

  private

  def capture_exception_with_sentry
    Sentry.with_scope do |scope|
      scope.set_user(id: @user.id, email: @user.email) if @user.is_a?(User)
      Sentry.capture_exception(@exception)
    end
  end
end
