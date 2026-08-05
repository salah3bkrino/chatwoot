# frozen_string_literal: true

class Workflow < ApplicationRecord
  NODE_TYPES = %w[trigger condition action ai_prompt].freeze
  CONDITION_ATTRIBUTES = %w[
    message_content
    conversation_status
    conversation_priority
    contact_email
  ].freeze
  CONDITION_OPERATORS = %w[contains equals not_equals present].freeze
  ACTION_TYPES = %w[send_message add_label assign_agent assign_team send_webhook].freeze

  belongs_to :account

  validates :name, presence: true, uniqueness: { scope: :account_id } # rubocop:disable Rails/UniqueValidationWithoutIndex
  validates :trigger_event,
            presence: true,
            inclusion: { in: %w[message_created conversation_created conversation_updated conversation_opened conversation_resolved] }
  validate :validate_nodes_structure
  validate :validate_edges_structure

  scope :active, -> { where(active: true) }

  private

  def validate_nodes_structure
    unless nodes.is_a?(Array)
      errors.add(:nodes, 'must be an array')
      return
    end

    nodes.each do |node|
      data = node['data'] || {}
      node_type = data['type'] || node['type'] if node.is_a?(Hash)

      unless node.is_a?(Hash) && node['id'].present? && NODE_TYPES.include?(node_type)
        errors.add(:nodes, 'each node must have an id and a supported type')
        break
      end

      validate_condition_node(data) if node_type == 'condition'
      validate_action_node(data) if node_type == 'action'
    end
  end

  def validate_edges_structure
    unless edges.is_a?(Array)
      errors.add(:edges, 'must be an array')
      return
    end

    edges.each do |edge|
      unless edge.is_a?(Hash) && edge['id'].present? && edge['source'].present? && edge['target'].present?
        errors.add(:edges, 'each edge must have an id, source, and target')
        break
      end
    end
  end

  def validate_condition_node(data)
    valid_condition = CONDITION_ATTRIBUTES.include?(data['attribute']) &&
                      CONDITION_OPERATORS.include?(data['operator']) &&
                      (data['operator'] == 'present' || data['value'].present?)
    errors.add(:nodes, 'condition nodes need a supported attribute, operator, and value') unless valid_condition
  end

  def validate_action_node(data)
    params = data['action_params'] || {}
    action = data['action_name']
    return errors.add(:nodes, 'action nodes need a supported action') unless ACTION_TYPES.include?(action)

    required_param = {
      'send_message' => 'content',
      'add_label' => 'label',
      'assign_agent' => 'agent_id',
      'assign_team' => 'team_id',
      'send_webhook' => 'url'
    }.fetch(action)

    errors.add(:nodes, "#{action} needs #{required_param}") if params[required_param].blank?
  end
end
