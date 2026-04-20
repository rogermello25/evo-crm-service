# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentBotInbox do
  describe '#set_default_configurations' do
    it 'defaults status to active when status is not set' do
      agent_bot_inbox = described_class.new

      agent_bot_inbox.send(:set_default_configurations)

      expect(agent_bot_inbox.status).to eq('active')
    end

    it 'does not override an explicit status' do
      agent_bot_inbox = described_class.new(status: :inactive)

      agent_bot_inbox.send(:set_default_configurations)

      expect(agent_bot_inbox.status).to eq('inactive')
    end
  end
end
