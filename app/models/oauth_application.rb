# == Schema Information
#
# Table name: oauth_applications
#
#  id           :uuid             not null, primary key
#  confidential :boolean          default(TRUE), not null
#  name         :string           not null
#  redirect_uri :text             not null
#  scopes       :string           default(""), not null
#  secret       :string           not null
#  trusted      :boolean          default(FALSE), not null
#  uid          :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_oauth_applications_on_uid  (uid) UNIQUE
#
class OauthApplication < Doorkeeper::Application
  validates :trusted, inclusion: { in: [true, false] }

  scope :dynamic_apps, -> { where('name LIKE ?', 'Dynamic OAuth -%') }
  scope :static_apps, -> { where.not('name LIKE ?', 'Dynamic OAuth -%') }

  def display_secret
    if trusted?
      secret
    else
      secret[0..7] + ('*' * (secret.length - 8))
    end
  end

  def dynamic_oauth_app?
    DynamicOauthService.is_dynamic_client_id?(uid)
  end

  def static_oauth_app?
    !dynamic_oauth_app?
  end

  def self.find_or_create_dynamic(user, redirect_uri = nil)
    DynamicOauthService.create_or_find_dynamic_application(
      DynamicOauthService.generate_dynamic_client_id,
      user,
      redirect_uri
    )
  end
end
