# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Avatarable do
  describe '#avatar_url' do
    let(:inbox) { Inbox.allocate }
    let(:avatar) { double('avatar') }
    let(:representation) { double('representation') }

    before do
      allow(inbox).to receive(:avatar).and_return(avatar)
      allow(inbox).to receive(:id).and_return(123)
    end

    context 'when avatar is attached and representable' do
      it 'returns variant URL' do
        allow(avatar).to receive(:attached?).and_return(true)
        allow(avatar).to receive(:representable?).and_return(true)
        allow(avatar).to receive(:representation).with(resize_to_fill: [250, nil]).and_return(representation)
        allow(inbox).to receive(:url_for).with(representation).and_return('http://example.test/variant.png')

        expect(inbox.avatar_url).to eq('http://example.test/variant.png')
      end
    end

    context 'when avatar is attached but not representable' do
      it 'falls back to blob URL' do
        allow(avatar).to receive(:attached?).and_return(true)
        allow(avatar).to receive(:representable?).and_return(false)
        allow(inbox).to receive(:url_for).with(avatar).and_return('http://example.test/blob.png')
        allow(Rails.logger).to receive(:warn)

        expect(inbox.avatar_url).to eq('http://example.test/blob.png')
        expect(Rails.logger).to have_received(:warn).with(/\[Avatarable\] Non-representable avatar fallback/)
      end
    end

    context 'when avatar is not attached' do
      it 'returns an empty string' do
        allow(avatar).to receive(:attached?).and_return(false)

        expect(inbox.avatar_url).to eq('')
      end
    end

    context 'when variant generation fails' do
      it 'falls back to blob URL' do
        allow(avatar).to receive(:attached?).and_return(true)
        allow(avatar).to receive(:representable?).and_return(true)
        allow(avatar).to receive(:representation).with(resize_to_fill: [250, nil]).and_raise(StandardError.new('processing error'))
        allow(inbox).to receive(:url_for).with(avatar).and_return('http://example.test/blob.png')
        allow(Rails.logger).to receive(:error)

        expect(inbox.avatar_url).to eq('http://example.test/blob.png')
        expect(Rails.logger).to have_received(:error).with(/\[Avatarable\] Avatar variant generation failed/)
      end
    end

    context 'when blob URL generation fails' do
      it 'returns empty string' do
        allow(avatar).to receive(:attached?).and_return(true)
        allow(avatar).to receive(:representable?).and_return(false)
        allow(inbox).to receive(:url_for).with(avatar).and_raise(StandardError.new('blob url error'))
        allow(Rails.logger).to receive(:error)

        expect(inbox.avatar_url).to eq('')
        expect(Rails.logger).to have_received(:error).with(/\[Avatarable\] Avatar blob URL generation failed/)
      end
    end
  end
end
