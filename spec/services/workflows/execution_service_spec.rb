require 'rails_helper'

RSpec.describe Workflows::ExecutionService, type: :service do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, account: account, conversation: conversation, content: 'Need support') }
  let(:workflow) do
    Workflow.create!(
      account: account,
      name: 'Workflow test',
      trigger_event: 'message_created',
      nodes: nodes,
      edges: edges
    )
  end
  let(:service) do
    described_class.new(
      workflow: workflow,
      event_name: 'message_created',
      event_data: { message: message }
    )
  end
  let(:nodes) do
    [
      { 'id' => 'trigger', 'data' => { 'type' => 'trigger' } },
      { 'id' => 'action', 'data' => { 'type' => 'action', 'action_name' => 'add_label', 'action_params' => { 'label' => 'support' } } }
    ]
  end
  let(:edges) { [{ 'id' => 'trigger-action', 'source' => 'trigger', 'target' => 'action' }] }

  describe '#perform' do
    it 'executes a connected action' do
      expect { service.perform }.to change { conversation.reload.label_list }.from([]).to(['support'])
    end

    context 'with a matching condition' do
      let(:nodes) do
        [
          { 'id' => 'trigger', 'data' => { 'type' => 'trigger' } },
          {
            'id' => 'condition',
            'data' => { 'type' => 'condition', 'attribute' => 'message_content', 'operator' => 'contains', 'value' => 'support' }
          },
          { 'id' => 'action', 'data' => { 'type' => 'action', 'action_name' => 'add_label', 'action_params' => { 'label' => 'matched' } } }
        ]
      end
      let(:edges) do
        [
          { 'id' => 'trigger-condition', 'source' => 'trigger', 'target' => 'condition' },
          { 'id' => 'condition-action', 'source' => 'condition', 'target' => 'action' }
        ]
      end

      it 'follows the connected path' do
        expect { service.perform }.to change { conversation.reload.label_list }.from([]).to(['matched'])
      end
    end

    context 'with a non-matching condition' do
      let(:nodes) do
        [
          { 'id' => 'trigger', 'data' => { 'type' => 'trigger' } },
          {
            'id' => 'condition',
            'data' => { 'type' => 'condition', 'attribute' => 'message_content', 'operator' => 'contains', 'value' => 'sales' }
          },
          { 'id' => 'action', 'data' => { 'type' => 'action', 'action_name' => 'add_label', 'action_params' => { 'label' => 'matched' } } }
        ]
      end
      let(:edges) do
        [
          { 'id' => 'trigger-condition', 'source' => 'trigger', 'target' => 'condition' },
          { 'id' => 'condition-action', 'source' => 'condition', 'target' => 'action' }
        ]
      end

      it 'does not execute the action' do
        expect { service.perform }.not_to change { conversation.reload.label_list }
      end
    end

    it 'queues a configured webhook' do
      workflow.update!(
        nodes: [
          { 'id' => 'trigger', 'data' => { 'type' => 'trigger' } },
          {
            'id' => 'webhook',
            'data' => {
              'type' => 'action',
              'action_name' => 'send_webhook',
              'action_params' => { 'url' => 'https://example.com/workflows' }
            }
          }
        ],
        edges: [{ 'id' => 'trigger-webhook', 'source' => 'trigger', 'target' => 'webhook' }]
      )

      expect(WebhookJob).to receive(:perform_later).with(
        'https://example.com/workflows',
        hash_including(event: 'workflow.executed', workflow_id: workflow.id)
      )

      service.perform
    end
  end
end
