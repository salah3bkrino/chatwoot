# frozen_string_literal: true

class Conversations::EvaluateAiResolutionJob < ApplicationJob
  queue_as :low

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.blank?
    return unless conversation.account.feature_enabled?('ai_resolution_tracking')

    Captain::Llm::ResolutionEvaluationService.new(conversation).perform
  end
end
