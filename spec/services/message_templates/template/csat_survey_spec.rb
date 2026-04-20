# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MessageTemplates::Template::CsatSurvey do
  let(:inbox) { create(:inbox) }
  let(:contact) { create(:contact) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) { create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }
  let(:service) { described_class.new(conversation: conversation) }

  describe '#should_send_csat_survey?' do
    context 'when no survey rules are configured' do
      before do
        inbox.update(csat_config: nil)
      end

      it 'returns true' do
        expect(service.send(:should_send_csat_survey?)).to be true
      end
    end

    context 'with triggers array format' do
      context 'with label trigger' do
        before do
          inbox.update(csat_config: {
            'survey_rules' => {
              'triggers' => [
                {
                  'type' => 'label',
                  'operator' => 'contains',
                  'values' => ['label1']
                }
              ]
            }
          })
        end

        context 'when conversation has matching label' do
          before do
            conversation.update(cached_label_list: 'label1')
          end

          it 'returns true' do
            expect(service.send(:should_send_csat_survey?)).to be true
          end
        end

        context 'when conversation does not have matching label' do
          before do
            conversation.update(cached_label_list: 'label2')
          end

          it 'returns false' do
            expect(service.send(:should_send_csat_survey?)).to be false
          end
        end
      end

      context 'with stage trigger' do
        let(:pipeline) { create(:pipeline) }
        let(:stage1) { create(:pipeline_stage, pipeline: pipeline, name: 'Stage 1') }
        let(:stage2) { create(:pipeline_stage, pipeline: pipeline, name: 'Stage 2') }
        let!(:pipeline_item) { create(:pipeline_item, conversation: conversation, pipeline: pipeline, pipeline_stage: stage1) }

        context 'with stage_ids' do
          before do
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'stage',
                    'operator' => 'equals',
                    'stage_ids' => [stage1.id.to_s]
                  }
                ]
              }
            })
          end

          context 'when conversation is in matching stage' do
            it 'returns true' do
              expect(service.send(:should_send_csat_survey?)).to be true
            end
          end

          context 'when conversation is not in matching stage' do
            before do
              pipeline_item.update(pipeline_stage: stage2)
            end

            it 'returns false' do
              expect(service.send(:should_send_csat_survey?)).to be false
            end
          end
        end

        context 'with stage_names' do
          before do
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'stage',
                    'operator' => 'equals',
                    'stage_names' => ['Stage 1']
                  }
                ]
              }
            })
          end

          context 'when conversation is in matching stage' do
            it 'returns true' do
              expect(service.send(:should_send_csat_survey?)).to be true
            end
          end

          context 'when conversation is not in matching stage' do
            before do
              pipeline_item.update(pipeline_stage: stage2)
            end

            it 'returns false' do
              expect(service.send(:should_send_csat_survey?)).to be false
            end
          end
        end

        context 'with not_equals operator' do
          before do
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'stage',
                    'operator' => 'not_equals',
                    'stage_ids' => [stage1.id.to_s]
                  }
                ]
              }
            })
          end

          context 'when conversation is not in the excluded stage' do
            before do
              pipeline_item.update(pipeline_stage: stage2)
            end

            it 'returns true' do
              expect(service.send(:should_send_csat_survey?)).to be true
            end
          end

          context 'when conversation is in the excluded stage' do
            it 'returns false' do
              expect(service.send(:should_send_csat_survey?)).to be false
            end
          end
        end

        context 'when conversation has no pipeline_item' do
          before do
            pipeline_item.destroy
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'stage',
                    'operator' => 'equals',
                    'stage_ids' => [stage1.id.to_s]
                  }
                ]
              }
            })
          end

          it 'returns false' do
            expect(service.send(:should_send_csat_survey?)).to be false
          end
        end

        context 'when stage_ids and stage_names are empty' do
          before do
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'stage',
                    'operator' => 'equals',
                    'stage_ids' => [],
                    'stage_names' => []
                  }
                ]
              }
            })
          end

          it 'returns true' do
            expect(service.send(:should_send_csat_survey?)).to be true
          end
        end
      end

      context 'with regex trigger' do
        let!(:message) { create(:message, conversation: conversation, content: 'Hello world', inbox: inbox) }

        context 'when message content matches pattern' do
          before do
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'regex',
                    'field' => 'message_content',
                    'pattern' => 'Hello.*'
                  }
                ]
              }
            })
          end

          it 'returns true' do
            expect(service.send(:should_send_csat_survey?)).to be true
          end
        end

        context 'when message content does not match pattern' do
          before do
            message.update(content: 'Goodbye world')
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'regex',
                    'field' => 'message_content',
                    'pattern' => 'Hello.*'
                  }
                ]
              }
            })
          end

          it 'returns false' do
            expect(service.send(:should_send_csat_survey?)).to be false
          end
        end

        context 'when pattern is invalid' do
          before do
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'regex',
                    'field' => 'message_content',
                    'pattern' => '[invalid regex'
                  }
                ]
              }
            })
          end

          it 'returns false' do
            expect(service.send(:should_send_csat_survey?)).to be false
          end
        end

        context 'when pattern is blank' do
          before do
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'regex',
                    'field' => 'message_content',
                    'pattern' => ''
                  }
                ]
              }
            })
          end

          it 'returns false' do
            expect(service.send(:should_send_csat_survey?)).to be false
          end
        end

        context 'when conversation has no messages' do
          before do
            conversation.messages.destroy_all
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'regex',
                    'field' => 'message_content',
                    'pattern' => 'Hello.*'
                  }
                ]
              }
            })
          end

          it 'returns false' do
            expect(service.send(:should_send_csat_survey?)).to be false
          end
        end

        context 'with case-insensitive pattern matching' do
          before do
            message.update(content: 'HELLO WORLD')
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'regex',
                    'field' => 'message_content',
                    'pattern' => 'hello.*'
                  }
                ]
              }
            })
          end

          it 'returns true' do
            expect(service.send(:should_send_csat_survey?)).to be true
          end
        end
      end

      context 'with inactivity trigger' do
        context 'when conversation is inactive for more than threshold' do
          before do
            conversation.update(last_activity_at: 31.minutes.ago)
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'inactivity',
                    'minutes' => 30
                  }
                ]
              }
            })
          end

          it 'returns true' do
            expect(service.send(:should_send_csat_survey?)).to be true
          end
        end

        context 'when conversation is inactive exactly at threshold' do
          before do
            conversation.update(last_activity_at: 30.minutes.ago)
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'inactivity',
                    'minutes' => 30
                  }
                ]
              }
            })
          end

          it 'returns true' do
            expect(service.send(:should_send_csat_survey?)).to be true
          end
        end

        context 'when conversation is active' do
          before do
            conversation.update(last_activity_at: 10.minutes.ago)
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'inactivity',
                    'minutes' => 30
                  }
                ]
              }
            })
          end

          it 'returns false' do
            expect(service.send(:should_send_csat_survey?)).to be false
          end
        end

        context 'when last_activity_at is nil' do
          before do
            conversation.update(last_activity_at: nil, updated_at: 31.minutes.ago)
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'inactivity',
                    'minutes' => 30
                  }
                ]
              }
            })
          end

          it 'uses updated_at and returns true' do
            expect(service.send(:should_send_csat_survey?)).to be true
          end
        end

        context 'when minutes is not numeric' do
          before do
            conversation.update(last_activity_at: 31.minutes.ago)
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'inactivity',
                    'minutes' => 'invalid'
                  }
                ]
              }
            })
          end

          it 'returns false' do
            expect(service.send(:should_send_csat_survey?)).to be false
          end
        end

        context 'when minutes is zero' do
          before do
            conversation.update(last_activity_at: 31.minutes.ago)
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'inactivity',
                    'minutes' => 0
                  }
                ]
              }
            })
          end

          it 'returns false' do
            expect(service.send(:should_send_csat_survey?)).to be false
          end
        end

        context 'when minutes is negative' do
          before do
            conversation.update(last_activity_at: 31.minutes.ago)
            inbox.update(csat_config: {
              'survey_rules' => {
                'triggers' => [
                  {
                    'type' => 'inactivity',
                    'minutes' => -10
                  }
                ]
              }
            })
          end

          it 'returns false' do
            expect(service.send(:should_send_csat_survey?)).to be false
          end
        end
      end

      context 'with multiple triggers' do
        before do
          inbox.update(csat_config: {
            'survey_rules' => {
              'triggers' => [
                {
                  'type' => 'label',
                  'operator' => 'contains',
                  'values' => ['label1']
                },
                {
                  'type' => 'inactivity',
                  'minutes' => 30
                }
              ]
            }
          })
        end

        context 'when at least one trigger matches' do
          before do
            conversation.update(cached_label_list: 'label1')
          end

          it 'returns true' do
            expect(service.send(:should_send_csat_survey?)).to be true
          end
        end

        context 'when no triggers match' do
          before do
            conversation.update(cached_label_list: 'label2', last_activity_at: 10.minutes.ago)
          end

          it 'returns false' do
            expect(service.send(:should_send_csat_survey?)).to be false
          end
        end
      end
    end
  end
end
