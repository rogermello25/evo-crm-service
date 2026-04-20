# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ConversationReplyMailer email signature rendering' do
  let(:templates_path) { Rails.root.join('app/views/mailers/conversation_reply_mailer') }

  let(:channel_with_signature) do
    double('Channel::Email', email_signature: '<p><strong>John Doe</strong><br/>Acme Corp</p>')
  end

  let(:channel_without_signature) do
    double('Channel::Email', email_signature: nil)
  end

  let(:plain_message) do
    msg = double('Message', content: 'Hello, this is a test.', content_type: 'text',
                            message_type: 'outgoing', attachments: [])
    allow(msg).to receive(:template?).and_return(false)
    allow(msg).to receive(:input_csat?).and_return(false)
    allow(msg).to receive(:incoming?).and_return(false)
    sender = double('User', available_name: 'Agent', name: 'Agent')
    allow(msg).to receive(:sender).and_return(sender)
    msg
  end

  describe 'email_reply.html.erb' do
    let(:template_file) { templates_path.join('email_reply.html.erb') }
    let(:template) { File.read(template_file) }

    context 'when channel has a signature' do
      it 'renders the signature in the output' do
        @channel = channel_with_signature
        @message = plain_message
        @large_attachments = []
        renderer = ERB.new(template)
        output = renderer.result(binding)

        expect(output).to include('John Doe')
        expect(output).to include('Acme Corp')
        expect(output).to include('border-top: 1px solid #e0e0e0')
      end
    end

    context 'when channel has no signature' do
      it 'does not render a signature block' do
        @channel = channel_without_signature
        @message = plain_message
        @large_attachments = []
        renderer = ERB.new(template)
        output = renderer.result(binding)

        expect(output).not_to include('border-top: 1px solid #e0e0e0')
        expect(output).not_to include('John Doe')
      end
    end
  end

  describe 'reply_with_summary.html.erb' do
    let(:template_file) { templates_path.join('reply_with_summary.html.erb') }
    let(:template) { File.read(template_file) }

    let(:contact) { double('Contact', name: 'Test Contact') }

    context 'when channel has a signature' do
      it 'renders the signature in the output' do
        @channel = channel_with_signature
        @contact = contact
        @messages = [plain_message]
        renderer = ERB.new(template)
        output = renderer.result(binding)

        expect(output).to include('John Doe')
        expect(output).to include('Acme Corp')
        expect(output).to include('border-top: 1px solid #e0e0e0')
      end
    end

    context 'when channel has no signature' do
      it 'does not render a signature block' do
        @channel = channel_without_signature
        @contact = contact
        @messages = [plain_message]
        renderer = ERB.new(template)
        output = renderer.result(binding)

        expect(output).not_to include('border-top: 1px solid #e0e0e0')
      end
    end
  end

  describe 'reply_without_summary.html.erb' do
    let(:template_file) { templates_path.join('reply_without_summary.html.erb') }
    let(:template) { File.read(template_file) }

    context 'when channel has a signature' do
      it 'renders the signature in the output' do
        @channel = channel_with_signature
        @messages = [plain_message]
        renderer = ERB.new(template)
        output = renderer.result(binding)

        expect(output).to include('John Doe')
        expect(output).to include('Acme Corp')
        expect(output).to include('border-top: 1px solid #e0e0e0')
      end
    end

    context 'when channel has no signature' do
      it 'does not render a signature block' do
        @channel = channel_without_signature
        @messages = [plain_message]
        renderer = ERB.new(template)
        output = renderer.result(binding)

        expect(output).not_to include('border-top: 1px solid #e0e0e0')
      end
    end
  end
end
