# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationSerializer do
  include ActiveSupport::Testing::TimeHelpers

  describe '.serialize' do
    it 'includes timestamp field matching last_activity_at' do
      activity_time = Time.zone.parse('2026-02-12 10:00:00')

      conversation = double('Conversation',
        as_json: { 'id' => 1, 'inbox_id' => 1, 'status' => 'open',
                   'assignee_id' => nil, 'team_id' => nil, 'campaign_id' => nil,
                   'display_id' => 1, 'additional_attributes' => {}, 'priority' => nil },
        created_at: activity_time,
        updated_at: activity_time,
        agent_last_seen_at: nil,
        contact_last_seen_at: nil,
        waiting_since: nil,
        first_reply_created_at: nil,
        snoozed_until: nil,
        last_activity_at: activity_time,
        custom_attributes: {},
        unread_incoming_messages: double('Relation', count: 0),
        contact: nil,
        inbox: nil,
        assignee: nil,
        team: nil,
        cached_label_list_array: [],
        messages: double('Relation', last: nil))

      allow(conversation).to receive(:association).and_return(double(loaded?: false))

      result = described_class.serialize(conversation, include_contact: false, include_inbox: false)

      expect(result['timestamp']).to eq(activity_time.to_i)
      expect(result['timestamp']).to eq(result['last_activity_at'])
    end

    it 'returns nil timestamp when last_activity_at is nil' do
      now = Time.zone.parse('2026-02-12 11:00:00')

      conversation = double('Conversation',
        as_json: { 'id' => 2, 'inbox_id' => 1, 'status' => 'open',
                   'assignee_id' => nil, 'team_id' => nil, 'campaign_id' => nil,
                   'display_id' => 2, 'additional_attributes' => {}, 'priority' => nil },
        created_at: now,
        updated_at: now,
        agent_last_seen_at: nil,
        contact_last_seen_at: nil,
        waiting_since: nil,
        first_reply_created_at: nil,
        snoozed_until: nil,
        last_activity_at: nil,
        custom_attributes: {},
        unread_incoming_messages: double('Relation', count: 0),
        contact: nil,
        inbox: nil,
        assignee: nil,
        team: nil,
        cached_label_list_array: [],
        messages: double('Relation', last: nil))

      allow(conversation).to receive(:association).and_return(double(loaded?: false))

      result = described_class.serialize(conversation, include_contact: false, include_inbox: false)

      expect(result['timestamp']).to be_nil
      expect(result['last_activity_at']).to be_nil
    end
  end
end
