class Workflows::ExecutionService
  pattr_initialize [:workflow!, :event_name!, :event_data!]

  MAX_NODES = 50
  WEBHOOK_TIMEOUT_SECONDS = 5
  SPECIAL_OPERATORS = %w[has_flow_response flow_name_equals has_ad_referral].freeze
  SAFE_TARGET_METHODS = %w[
    content processed_message_content message_type content_type status priority team_id
    assignee_id inbox_id account_id contact_id display_id sender_id private source_id label_list
  ].freeze
  OPERATORS = {
    'contains' => ->(val, exp) { !val.nil? && val.to_s.downcase.include?(exp.to_s.downcase) },
    'equals' => ->(val, exp) { !val.nil? && val.to_s.downcase == exp.to_s.downcase },
    'not_equals' => ->(val, exp) { val.to_s.downcase != exp.to_s.downcase },
    'present' => ->(val, _exp) { val.present? }
  }.freeze
  ACTION_HANDLERS = {
    'send_message' => :send_message, 'add_label' => :add_label, 'trigger_webhook' => :trigger_webhook,
    'assign_team' => :assign_team, 'resolve_conversation' => :resolve_target_conversation
  }.freeze

  def perform
    previous = Current.executed_by
    return unless workflow.active?

    Current.executed_by = workflow
    @visited_nodes = Set.new
    execute_node(workflow.nodes.find { |n| n['type'] == 'trigger' })
  rescue StandardError => e
    Rails.logger.error("[Workflows] Execution failed for workflow #{workflow.id}: #{e.message}")
  ensure
    Current.executed_by = previous
  end

  private

  def execute_node(node)
    return if skip_node?(node)

    @visited_nodes.add(node['id'])
    dispatch_node(node)
  end

  def skip_node?(node) = node.nil? || @visited_nodes.include?(node['id']) || @visited_nodes.size >= MAX_NODES

  def dispatch_node(node)
    case node['type']
    when 'trigger' then follow_edges(node['id'])
    when 'condition' then follow_edges(node['id'], evaluate_condition(node['data']).to_s)
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

  def evaluate_condition(data)
    target = fetch_target_object
    return false unless target && data.is_a?(Hash)

    condition = data.stringify_keys
    operator = condition['operator'].presence
    attribute = SPECIAL_OPERATORS.include?(operator) ? operator : condition['attribute'].to_s
    effective_operator = SPECIAL_OPERATORS.include?(operator) ? default_operator_for(operator) : (operator || default_operator_for(attribute))
    attr_value = resolve_condition_value(condition, attribute, target)
    apply_operator(attr_value, effective_operator, condition['value'])
  end

  def default_operator_for(attribute) = %w[has_flow_response has_ad_referral].include?(attribute.to_s) ? 'present' : 'equals'

  def resolve_condition_value(condition, attribute, target)
    return flow_field_value(target, condition['flow_field']) if condition['flow_field'].present?
    return nil if attribute.blank?
    return flow_field_value(target, attribute.delete_prefix('flow_field:')) if attribute.start_with?('flow_field:')

    resolve_attribute(attribute, target)
  end

  def resolve_attribute(attribute, target)
    message = message_from(target)
    case attribute
    when 'has_flow_response' then flow_response_payload(message).present?
    when 'flow_name', 'flow_name_equals' then flow_response_payload(message)['name']
    when 'interactive_reply_id' then stringify_hash(message&.content_attributes).dig('whatsapp_interactive_reply', 'id')
    when 'has_ad_referral' then ad_referral_present?(message, resolve_conversation(target))
    else standard_attribute_value(target, attribute)
    end
  end

  def standard_attribute_value(target, attribute)
    if target.respond_to?(attribute) && (SAFE_TARGET_METHODS.include?(attribute) || target.class.try(:column_names)&.include?(attribute))
      return target.public_send(attribute)
    end

    custom_attrs = stringify_hash(target.try(:custom_attributes))
    custom_attrs.key?(attribute) ? custom_attrs[attribute] : stringify_hash(target.try(:additional_attributes))[attribute]
  end

  def apply_operator(attr_value, operator, expected)
    return match_regex(attr_value, expected) if operator == 'regex'

    matcher = OPERATORS[operator]
    matcher ? matcher.call(attr_value, expected) : false
  end

  def match_regex(attr_value, pattern)
    return false if attr_value.nil? || pattern.blank?

    Regexp.new(pattern.to_s, Regexp::IGNORECASE).match?(attr_value.to_s)
  rescue RegexpError => e
    Rails.logger.warn("[Workflows] Invalid regex pattern in workflow #{workflow.id}: #{e.message}")
    false
  end

  def flow_field_value(target, field_key)
    json = flow_response_payload(message_from(target))['response_json']
    return nil unless json.is_a?(Hash)

    key = field_key.to_s
    json.key?(key) ? json[key] : (json.dig(*key.split('.')) if key.include?('.'))
  end

  def flow_response_payload(message)
    flow = stringify_hash(stringify_hash(message&.content_attributes)['whatsapp_flow_response'])
    return {} if flow.empty?

    raw = flow['response_json']
    flow.merge('response_json' => stringify_hash(raw.is_a?(String) ? JSON.parse(raw) : raw))
  rescue JSON::ParserError
    flow.merge('response_json' => {})
  end

  def ad_referral_present?(message, conversation)
    [message&.content_attributes, message&.additional_attributes, conversation&.additional_attributes]
      .any? { |attrs| stringify_hash(attrs)['referral'].present? }
  end

  def stringify_hash(value) = value.is_a?(Hash) ? value.deep_stringify_keys : {}

  def execute_action(data)
    conversation = resolve_conversation(fetch_target_object)
    handler = data.is_a?(Hash) ? ACTION_HANDLERS[data['action_name']] : nil
    return unless conversation && handler

    params = data['action_params'].is_a?(Hash) ? data['action_params'].with_indifferent_access : {}
    send(handler, conversation, params)
  end

  def resolve_target_conversation(conversation, _params)
    conversation.resolved! unless conversation.resolved?
  end

  def execute_ai_prompt(_data) = Rails.logger.info('[Workflows] AI Prompt node encountered — not yet implemented for MVP')

  def fetch_target_object
    return event_data[:message] if event_name == 'message_created'

    event_data[:conversation] if %w[conversation_created conversation_updated conversation_opened conversation_resolved].include?(event_name)
  end

  def message_from(target) = target.is_a?(Conversation) ? nil : target

  def resolve_conversation(target) = target.is_a?(Conversation) ? target : target.try(:conversation)

  def send_message(conversation, params)
    content_attrs = { workflow_id: workflow.id }
    content_attrs[:items] = params[:items] if params[:items].present?
    content_attrs[:whatsapp_interactive] = params[:whatsapp_interactive] if params[:whatsapp_interactive].present?
    attrs = { conversation: conversation, account: conversation.account, sender: nil,
              content: params[:content], message_type: :outgoing, content_attributes: content_attrs }
    attrs[:content_type] = params[:content_type] if params[:content_type].present? && Message.content_types.key?(params[:content_type].to_s)
    Message.create!(attrs)
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    Rails.logger.warn("[Workflows] send_message failed: #{e.message}")
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

    target = fetch_target_object
    payload = { event: event_name, workflow_id: workflow.id, account_id: conversation.account_id,
                conversation: conversation.webhook_data, message: target.is_a?(Conversation) ? nil : target.try(:webhook_data) }
    response = HTTParty.post(url, body: payload.to_json, timeout: WEBHOOK_TIMEOUT_SECONDS,
                                  headers: { 'Content-Type' => 'application/json' }.merge(stringify_hash(params[:headers])))
    Rails.logger.warn("[Workflows] trigger_webhook returned #{response.code} for workflow #{workflow.id}") if response && !response.success?
  rescue StandardError => e
    Rails.logger.error("[Workflows] trigger_webhook failed for workflow #{workflow.id}: #{e.message}")
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
