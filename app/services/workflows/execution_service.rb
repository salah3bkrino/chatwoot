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
      follow_edges(node['id'], result.to_s)
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

    attribute = data['attribute'].to_s
    attr_value = if target.attributes.key?(attribute)
                   target.attributes[attribute]
                 else
                   target.try(:custom_attributes)&.dig(attribute)
                 end

    case data['operator']
    when 'contains'
      attr_value.to_s.downcase.include?(data['value'].to_s.downcase)
    when 'equals'
      attr_value.to_s.downcase == data['value'].to_s.downcase
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
    end
  end

  def execute_ai_prompt(_data)
    Rails.logger.info('[Workflows] AI Prompt node encountered — not yet implemented for MVP')
  end
  # rubocop:enable Metrics/CyclomaticComplexity

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

    conversation.label_list.add(label)
    conversation.save!
  end
end
