# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Channel::WebWidget, type: :model do
  let(:web_widget) { Channel::WebWidget.create!(website_url: 'https://example.com') }

  describe '#selected_feature_flags' do
    it 'returns empty array when no flags are enabled' do
      web_widget.update!(feature_flags: 0)
      expect(web_widget.selected_feature_flags).to eq([])
    end

    it 'returns array with attachments when only attachments flag is enabled' do
      web_widget.update!(feature_flags: 1)
      expect(web_widget.selected_feature_flags).to eq([:attachments])
    end

    it 'returns array with emoji_picker when only emoji_picker flag is enabled' do
      web_widget.update!(feature_flags: 2)
      expect(web_widget.selected_feature_flags).to eq([:emoji_picker])
    end

    it 'returns array with end_conversation when only end_conversation flag is enabled' do
      web_widget.update!(feature_flags: 8)
      expect(web_widget.selected_feature_flags).to eq([:end_conversation])
    end

    it 'returns array with use_inbox_avatar_for_bot when only use_inbox_avatar_for_bot flag is enabled' do
      web_widget.update!(feature_flags: 128)
      expect(web_widget.selected_feature_flags).to eq([:use_inbox_avatar_for_bot])
    end

    it 'returns array with all flags when all flags are enabled' do
      web_widget.update!(feature_flags: 139)
      expect(web_widget.selected_feature_flags).to contain_exactly(:attachments, :emoji_picker, :end_conversation, :use_inbox_avatar_for_bot)
    end

    it 'returns array with multiple flags when multiple flags are enabled' do
      web_widget.update!(feature_flags: 11)
      expect(web_widget.selected_feature_flags).to contain_exactly(:attachments, :emoji_picker, :end_conversation)
    end
  end

  describe '#selected_feature_flags=' do
    it 'sets all flags to false when empty array is provided' do
      web_widget.update!(feature_flags: 139)
      web_widget.selected_feature_flags = []
      web_widget.save!

      expect(web_widget.reload.feature_flags).to eq(0)
      expect(web_widget.attachments?).to be(false)
      expect(web_widget.emoji_picker?).to be(false)
      expect(web_widget.end_conversation?).to be(false)
      expect(web_widget.use_inbox_avatar_for_bot?).to be(false)
    end

    it 'enables only attachments flag when array contains :attachments' do
      web_widget.update!(feature_flags: 0)
      web_widget.selected_feature_flags = [:attachments]
      web_widget.save!

      expect(web_widget.reload.feature_flags).to eq(1)
      expect(web_widget.attachments?).to be(true)
      expect(web_widget.emoji_picker?).to be(false)
      expect(web_widget.end_conversation?).to be(false)
      expect(web_widget.use_inbox_avatar_for_bot?).to be(false)
    end

    it 'enables only emoji_picker flag when array contains :emoji_picker' do
      web_widget.update!(feature_flags: 0)
      web_widget.selected_feature_flags = [:emoji_picker]
      web_widget.save!

      expect(web_widget.reload.feature_flags).to eq(2)
      expect(web_widget.attachments?).to be(false)
      expect(web_widget.emoji_picker?).to be(true)
      expect(web_widget.end_conversation?).to be(false)
      expect(web_widget.use_inbox_avatar_for_bot?).to be(false)
    end

    it 'enables only end_conversation flag when array contains :end_conversation' do
      web_widget.update!(feature_flags: 0)
      web_widget.selected_feature_flags = [:end_conversation]
      web_widget.save!

      expect(web_widget.reload.feature_flags).to eq(8)
      expect(web_widget.attachments?).to be(false)
      expect(web_widget.emoji_picker?).to be(false)
      expect(web_widget.end_conversation?).to be(true)
      expect(web_widget.use_inbox_avatar_for_bot?).to be(false)
    end

    it 'enables only use_inbox_avatar_for_bot flag when array contains :use_inbox_avatar_for_bot' do
      web_widget.update!(feature_flags: 0)
      web_widget.selected_feature_flags = [:use_inbox_avatar_for_bot]
      web_widget.save!

      expect(web_widget.reload.feature_flags).to eq(128)
      expect(web_widget.attachments?).to be(false)
      expect(web_widget.emoji_picker?).to be(false)
      expect(web_widget.end_conversation?).to be(false)
      expect(web_widget.use_inbox_avatar_for_bot?).to be(true)
    end

    it 'enables multiple flags when array contains multiple flags' do
      web_widget.update!(feature_flags: 0)
      web_widget.selected_feature_flags = [:attachments, :emoji_picker, :end_conversation]
      web_widget.save!

      expect(web_widget.reload.feature_flags).to eq(11)
      expect(web_widget.attachments?).to be(true)
      expect(web_widget.emoji_picker?).to be(true)
      expect(web_widget.end_conversation?).to be(true)
      expect(web_widget.use_inbox_avatar_for_bot?).to be(false)
    end

    it 'enables all flags when array contains all flags' do
      web_widget.update!(feature_flags: 0)
      web_widget.selected_feature_flags = [:attachments, :emoji_picker, :end_conversation, :use_inbox_avatar_for_bot]
      web_widget.save!

      expect(web_widget.reload.feature_flags).to eq(139)
      expect(web_widget.attachments?).to be(true)
      expect(web_widget.emoji_picker?).to be(true)
      expect(web_widget.end_conversation?).to be(true)
      expect(web_widget.use_inbox_avatar_for_bot?).to be(true)
    end

    it 'disables flags not in the array' do
      web_widget.update!(feature_flags: 139)
      web_widget.selected_feature_flags = [:attachments]
      web_widget.save!

      expect(web_widget.reload.feature_flags).to eq(1)
      expect(web_widget.attachments?).to be(true)
      expect(web_widget.emoji_picker?).to be(false)
      expect(web_widget.end_conversation?).to be(false)
      expect(web_widget.use_inbox_avatar_for_bot?).to be(false)
    end

    it 'accepts string flag names and converts them to symbols' do
      web_widget.update!(feature_flags: 0)
      web_widget.selected_feature_flags = ['attachments', 'emoji_picker']
      web_widget.save!

      expect(web_widget.reload.feature_flags).to eq(3)
      expect(web_widget.attachments?).to be(true)
      expect(web_widget.emoji_picker?).to be(true)
    end

    it 'persists changes to database after save' do
      web_widget.update!(feature_flags: 11)
      web_widget.selected_feature_flags = []
      web_widget.save!

      reloaded_widget = Channel::WebWidget.find(web_widget.id)
      expect(reloaded_widget.feature_flags).to eq(0)
      expect(reloaded_widget.selected_feature_flags).to eq([])
    end
  end

  describe 'locale validation' do
    it 'allows nil locale' do
      web_widget.locale = nil
      expect(web_widget).to be_valid
    end

    it 'allows supported locale' do
      web_widget.locale = 'pt_BR'
      expect(web_widget).to be_valid
    end

    it 'rejects unsupported locale' do
      web_widget.locale = 'de'
      expect(web_widget).not_to be_valid
      expect(web_widget.errors[:locale]).to include('is not included in the list')
    end
  end

  describe 'integration with controller update flow' do
    it 'allows setting flags via selected_feature_flags= and persists correctly' do
      web_widget.update!(feature_flags: 139)

      web_widget.selected_feature_flags = [:attachments, :end_conversation]
      web_widget.save!

      expect(web_widget.reload.selected_feature_flags).to contain_exactly(:attachments, :end_conversation)
      expect(web_widget.feature_flags).to eq(9)
    end
  end
end
