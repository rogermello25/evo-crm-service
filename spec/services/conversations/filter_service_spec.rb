# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Conversations::FilterService do
  describe '#conversations' do
    it 'orders by last_activity_at desc and paginates' do
      user = instance_double(User)
      service = described_class.new({}, user)

      relation = double('Relation')
      service.instance_variable_set(:@conversations, relation)

      expect(relation).to receive(:sort_on_last_activity_at).with(:desc).and_return(relation)
      expect(relation).to receive(:page).with(1).and_return(relation)

      service.conversations
    end
  end
end
