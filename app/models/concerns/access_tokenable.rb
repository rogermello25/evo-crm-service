module AccessTokenable
  extend ActiveSupport::Concern
  included do
    has_one :access_token, as: :owner, dependent: :destroy_async
    after_create :create_access_token_if_needed
  end

  private

  def create_access_token_if_needed
    return if access_token.present?

    create_access_token
  end
end
