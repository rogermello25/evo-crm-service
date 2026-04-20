# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationFinder do
  describe '#apply_sorting' do
    it 'defaults to last_activity_at desc when sort_by is missing' do
      user = instance_double(User, id: 1)
      finder = described_class.new(user, {})
      relation = double('Relation')

      expect(relation).to receive(:sort_on_last_activity_at).with('desc').and_return(relation)

      finder.send(:apply_sorting, relation)
    end

    it 'uses provided sort_by when available' do
      user = instance_double(User, id: 1)
      finder = described_class.new(user, { sort_by: 'created_at_asc' })
      relation = double('Relation')

      expect(relation).to receive(:sort_on_created_at).with('asc').and_return(relation)

      finder.send(:apply_sorting, relation)
    end
  end
end
