# frozen_string_literal: true

class Workflow < ApplicationRecord
  NODE_TYPES = %w[trigger condition action ai_prompt].freeze

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
      node_type = node.dig('data', 'type') || node['type'] if node.is_a?(Hash)

      unless node.is_a?(Hash) && node['id'].present? && NODE_TYPES.include?(node_type)
        errors.add(:nodes, 'each node must have an id and a supported type')
        break
      end
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
end
