# == Schema Information
#
# Table name: access_tokens
#
#  id         :uuid             not null, primary key
#  name       :string(255)      not null
#  owner_type :string
#  scopes     :string           not null
#  token      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  issued_id  :uuid
#  owner_id   :uuid
#
# Indexes
#
#  index_access_tokens_on_issued_id                (issued_id)
#  index_access_tokens_on_owner_type_and_owner_id  (owner_type,owner_id)
#  index_access_tokens_on_token                    (token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (issued_id => users.id)
#
class AccessToken < ApplicationRecord
  belongs_to :owner, polymorphic: true

  validates :token, presence: true, uniqueness: true

  before_create :generate_token

  def regenerate_token
    generate_token
    save!
  end

  private

  def generate_token
    self.token = SecureRandom.hex(32)
  end
end
