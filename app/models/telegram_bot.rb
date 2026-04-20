# == Schema Information
#
# Table name: telegram_bots
#
#  id         :uuid             not null, primary key
#  auth_key   :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class TelegramBot < ApplicationRecord
  has_one :inbox, as: :channel, dependent: :destroy_async
  validates :auth_key, uniqueness: true
end
