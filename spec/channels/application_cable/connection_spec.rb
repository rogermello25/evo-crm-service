# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { User.create!(name: 'Agent', email: "conn-#{SecureRandom.hex(4)}@test.com") }

  describe '#connect' do
    it 'identifies the user when warden provides one' do
      warden = double('warden', user: user)
      connect '/cable', env: { 'warden' => warden }

      expect(connection.warden_user).to eq(user)
    end

    it 'sets warden_user to nil when warden is absent' do
      connect '/cable', env: {}

      expect(connection.warden_user).to be_nil
    end

    it 'sets warden_user to nil when warden raises' do
      warden = double('warden')
      allow(warden).to receive(:user).and_raise(StandardError, 'boom')

      connect '/cable', env: { 'warden' => warden }

      expect(connection.warden_user).to be_nil
    end
  end
end
