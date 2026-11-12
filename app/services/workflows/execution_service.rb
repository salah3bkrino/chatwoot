class Workflows::ExecutionService
  pattr_initialize [:workflow!, :event_name!, :event_data!]

  MAX_NODES = 50
  WEBHOOK_TIMEOUT_SECONDS = 5
  ACTION_HANDLERS = {
    'send_message' => :send_message,
    'add_label' => :add_label,
    'trigger_webhook' => :trigger_webhook,
    'assign_team' => :assign_team,
    'resolve_conversation' => :resolve_target_conversation
  }.freeze

  def perform
    previous = Current.executed_by
    return unless workflow.active?

    Current.executed_by = workflow
    @visited_nodes = Set.new
    execute_node(workflow.nodes.find { |n| node_role(n) == 'trigger' })
  rescue StandardError => e
    Rails.logger.error("[Workflows] Execution failed for workflow #{workflow.id}: #{e.message}")
  ensure
    Current.executed_by = previous
  end

  private

  def node_role(node)
    return nil unless node.is_a?(Hash)

    node.dig('data', 'type').presence || node['type']
  end

  def execute_node(node)
    return if node.nil? || @visited_nodes.include?(node['id']) || @visited_nodes.size >= MAX_NODES

    @visited_nodes.add(node['id'])
    dispatch_node(node)
  end

  def dispatch_node(node)
    case node_role(node)
    when 'trigger' then follow_edges(node['id'])
    when 'condition' then follow_edges(node['id'], condition_evaluator.evaluate(node['data']).to_s)
    when 'action'
      execute_action(node['data'])
      follow_edges(node['id'])
    when 'ai_prompt'
      execute_ai_prompt(node['data'])
      follow_edges(node['id'])
    end
  end

  def follow_edges(node_id, source_handle = nil)
    node_edges = workflow.edges.select { |e| e['source'] == node_id }
    matched = source_handle.nil? ? node_edges : matching_condition_edges(node_edges, source_handle)
    matched.each { |edge| execute_node(workflow.nodes.find { |n| n['id'] == edge['target'] }) }
  end

  def matching_condition_edges(node_edges, source_handle)
    explicit = node_edges.select { |e| e['sourceHandle'].to_s == source_handle }
    has_branches = node_edges.any? { |e| %w[true false].include?(e['sourceHandle'].to_s) }
    return explicit if explicit.present? || has_branches || source_handle != 'true'

    node_edges.select { |e| e['sourceHandle'].blank? }
  end

  def condition_evaluator
    @condition_evaluator ||= Workflows::ConditionEvaluator.new(
      workflow: workflow, event_name: event_name, event_data: event_data
    )
  end

  def execute_action(data)
    target = condition_evaluator.target_object
    conversation = target.is_a?(Conversation) ? target : target.try(:conversation)
    handler = data.is_a?(Hash) ? ACTION_HANDLERS[data['action_name']] : nil
    return unless conversation && handler

    params = data['action_params'].is_a?(Hash) ? data['action_params'].with_indifferent_access : {}
    send(handler, conversation, params)
  end

  def resolve_target_conversation(conversation, _params)
    conversation.resolved! unless conversation.resolved?
  end

  def execute_ai_prompt(_data)
    Rails.logger.info('[Workflows] AI Prompt node encountered — not yet implemented for MVP')
  end

  def send_message(conversation, params)
    Message.create!(build_message_attributes(conversation, params))
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    Rails.logger.warn("[Workflows] send_message failed: #{e.message}")
  end

  def build_message_attributes(conversation, params)
    content_attrs = { workflow_id: workflow.id }
    content_attrs[:items] = params[:items] if params[:items].present?
    content_attrs[:whatsapp_interactive] = params[:whatsapp_interactive] if params[:whatsapp_interactive].present?
    attrs = {
      conversation: conversation, account: conversation.account, sender: nil,
      content: params[:content], message_type: :outgoing, content_attributes: content_attrs
    }
    requested_type = params[:content_type].to_s
    attrs[:content_type] = requested_type if requested_type.present? && Message.content_types.key?(requested_type)
    attrs
  end

  def add_label(conversation, params)
    label = params[:label].presence || params[:labels].presence
    return if label.blank?

    conversation.label_list.add(label)
    conversation.save!
  end

  def trigger_webhook(conversation, params)
    url = params[:url].to_s.strip
    return unless valid_webhook_url?(url)

    response = HTTParty.post(url, body: webhook_payload(conversation).to_json,
                                  timeout: WEBHOOK_TIMEOUT_SECONDS, headers: webhook_headers(params))
    Rails.logger.warn("[Workflows] trigger_webhook returned #{response.code} for workflow #{workflow.id}") unless response&.success?
  rescue StandardError => e
    Rails.logger.error("[Workflows] trigger_webhook failed for workflow #{workflow.id}: #{e.message}")
  end

  def webhook_payload(conversation)
    target = condition_evaluator.target_object
    {
      event: event_name, workflow_id: workflow.id, account_id: conversation.account_id,
      conversation: conversation.webhook_data,
      message: target.is_a?(Conversation) ? nil : target.try(:webhook_data)
    }
  end

  def webhook_headers(params)
    custom_headers = params[:headers].is_a?(Hash) ? params[:headers].deep_stringify_keys : {}
    { 'Content-Type' => 'application/json' }.merge(custom_headers)
  end

  def valid_webhook_url?(url)
    url.match?(%r{\Ahttps?://}i) && URI.parse(url).then { |uri| uri.is_a?(URI::HTTP) && uri.host.present? }
  rescue URI::InvalidURIError
    false
  end

  def assign_team(conversation, params)
    return if params[:team_id].blank? || !conversation.account.teams.exists?(id: params[:team_id])

    conversation.update!(team_id: params[:team_id])
  end
end
