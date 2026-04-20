module Channelable
  extend ActiveSupport::Concern
  included do
    has_one :inbox, as: :channel, dependent: :destroy_async, touch: true
  end
end

Channelable.prepend_mod_with('Channelable')
