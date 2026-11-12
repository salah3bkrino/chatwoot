class Workflows::ConditionEvaluator
  pattr_initialize [:workflow!, :event_name!, :event_data!]

  CONVERSATION_EVENTS = %w[
    conversation_created conversation_updated conversation_opened conversation_resolved
  ].freeze
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

  def evaluate(data)
    target = target_object
    return false unless target && data.is_a?(Hash)

    condition = data.stringify_keys
    attribute, operator = normalize_condition(condition)
    apply_operator(resolve_condition_value(condition, attribute, target), operator, condition['value'])
  end

  def target_object
    return event_data[:message] if event_name == 'message_created'

    event_data[:conversation] if CONVERSATION_EVENTS.include?(event_name)
  end

  private

  def normalize_condition(condition)
    raw_op = condition['operator'].presence
    return [raw_op, default_operator_for(raw_op)] if SPECIAL_OPERATORS.include?(raw_op)

    attribute = condition['attribute'].to_s
    [attribute, raw_op || default_operator_for(attribute)]
  end

  def default_operator_for(attribute)
    %w[has_flow_response has_ad_referral].include?(attribute.to_s) ? 'present' : 'equals'
  end

  def resolve_condition_value(condition, attribute, target)
    return flow_field_value(target, condition['flow_field']) if condition['flow_field'].present?
    return nil if attribute.blank?
    return flow_field_value(target, attribute.delete_prefix('flow_field:')) if attribute.start_with?('flow_field:')

    resolve_attribute(attribute, target)
  end

  def resolve_attribute(attribute, target)
    message = target.is_a?(Conversation) ? nil : target
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
    json = flow_response_payload(target.is_a?(Conversation) ? nil : target)['response_json']
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

  def resolve_conversation(target)
    target.is_a?(Conversation) ? target : target.try(:conversation)
  end

  def stringify_hash(value)
    value.is_a?(Hash) ? value.deep_stringify_keys : {}
  end
end
