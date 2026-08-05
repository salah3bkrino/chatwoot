class Workflows::ExecutionService
  pattr_initialize [:workflow!, :event_name!, :event_data!]

  MAX_NODES = 50

  def perform
    return unless workflow.active?

    @visited_nodes = Set.new
    trigger_node = workflow.nodes.find { |node| node_type(node) == 'trigger' }
    return unless trigger_node

    with_workflow_context do
      execute_node(trigger_node)
    end
  rescue StandardError => e
    Rails.logger.error("[Workflows] Execution failed for workflow #{workflow.id}: #{e.message}")
  end

  private

  # rubocop:disable Metrics/CyclomaticComplexity
  def execute_node(node)
    return if node.nil?
    return if @visited_nodes.include?(node['id'])
    return if @visited_nodes.size >= MAX_NODES

    @visited_nodes.add(node['id'])
    data = node['data'] || {}

    case node_type(node)
    when 'trigger'
      follow_edges(node['id'])
    when 'condition'
      result = evaluate_condition(data)
      follow_edges(node['id']) if result
    when 'action'
      execute_action(data)
      follow_edges(node['id'])
    when 'ai_prompt'
      execute_ai_prompt(data)
      follow_edges(node['id'])
    end
  end

  def follow_edges(node_id, source_handle = nil)
    matched_edges = workflow.edges.select { |e| e['source'] == node_id }
    matched_edges = matched_edges.select { |e| e['sourceHandle'] == source_handle } if source_handle

    matched_edges.each do |edge|
      next_node = workflow.nodes.find { |n| n['id'] == edge['target'] }
      execute_node(next_node)
    end
  end

  def evaluate_condition(data)
    target = fetch_target_object
    return false unless target

    attr_value = condition_value(data['attribute'])

    case data['operator']
    when 'contains'
      attr_value.to_s.downcase.include?(data['value'].to_s.downcase)
    when 'equals'
      attr_value.to_s.downcase == data['value'].to_s.downcase
    when 'not_equals'
      attr_value.to_s.downcase != data['value'].to_s.downcase
    when 'present'
      attr_value.present?
    else
      false
    end
  end

  def execute_action(data)
    target = fetch_target_object
    return unless target

    case data['action_name']
    when 'send_message'
      send_message(data['action_params'])
    when 'add_label'
      add_label(data['action_params'])
    when 'assign_agent'
      assign_agent(data['action_params'])
    when 'assign_team'
      assign_team(data['action_params'])
    when 'send_webhook'
      send_webhook(data['action_params'])
    end
  end

  def execute_ai_prompt(_data)
    Rails.logger.info('[Workflows] AI Prompt node encountered — not yet implemented for MVP')
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def condition_value(attribute)
    conversation = resolve_conversation(fetch_target_object)
    message = event_data[:message]

    case attribute
    when 'message_content'
      message&.content
    when 'conversation_status'
      conversation&.status
    when 'conversation_priority'
      conversation&.priority
    when 'contact_email'
      conversation&.contact&.email
    end
  end

  def fetch_target_object
    case event_name
    when 'message_created'
      event_data[:message]
    when 'conversation_created', 'conversation_updated', 'conversation_opened', 'conversation_resolved'
      event_data[:conversation]
    end
  end

  def resolve_conversation(target)
    target.is_a?(Conversation) ? target : target.try(:conversation)
  end

  def node_type(node)
    node.dig('data', 'type') || node['type'] if node.is_a?(Hash)
  end

  def with_workflow_context
    previous_executed_by = Current.executed_by
    Current.executed_by = workflow
    yield
  ensure
    Current.executed_by = previous_executed_by
  end

  def send_message(params)
    conversation = resolve_conversation(fetch_target_object)
    return unless conversation

    params ||= {}
    Messages::MessageBuilder.new(nil, conversation, {
      content: params['content'],
      private: false,
      content_attributes: { workflow_id: workflow.id }
    }).perform
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    Rails.logger.warn("[Workflows] send_message failed: #{e.message}")
  end

  def add_label(params)
    conversation = resolve_conversation(fetch_target_object)
    return unless conversation

    label = params&.fetch('label', nil).to_s
    return if label.blank?

    Label.find_or_create_by!(account: conversation.account, title: label)
    conversation.label_list.add(label)
    conversation.save!
  end

  def assign_agent(params)
    conversation = resolve_conversation(fetch_target_object)
    agent_id = params&.fetch('agent_id', nil).to_s
    return if conversation.blank? || agent_id.blank?

    ActionService.new(conversation).assign_agent([agent_id])
  end

  def assign_team(params)
    conversation = resolve_conversation(fetch_target_object)
    team_id = params&.fetch('team_id', nil).to_s
    return if conversation.blank? || team_id.blank?

    ActionService.new(conversation).assign_team([team_id])
  end

  def send_webhook(params)
    conversation = resolve_conversation(fetch_target_object)
    url = params&.fetch('url', nil).to_s
    return if conversation.blank? || url.blank?

    payload = conversation.webhook_data.merge(
      event: 'workflow.executed',
      workflow_id: workflow.id,
      workflow_name: workflow.name,
      trigger_event: event_name
    )
    WebhookJob.perform_later(url, payload)
  end
end
