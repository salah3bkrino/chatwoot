class CaptainListener < BaseListener
  # rubocop:disable Metrics/CyclomaticComplexity
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless message
    return if message.activity? || message.auto_reply_email?
    return unless message.incoming?

    Messages::DetectSentimentJob.perform_later(message.id) if message.account.feature_enabled?('sentiment_analysis')

    return unless message.account.feature_enabled?('auto_categorization') && message.conversation.messages.incoming.count == 3

    Conversations::AutoCategorizeJob.perform_later(message.conversation_id)
  end

  # rubocop:disable Metrics/PerceivedComplexity
  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    return unless conversation

    Conversations::EvaluateAiResolutionJob.perform_later(conversation.id) if conversation.account.feature_enabled?('ai_resolution_tracking')

    Conversations::EvaluateAutoQaJob.perform_later(conversation.id) if conversation.account.feature_enabled?('auto_qa')

    return unless conversation.inbox&.captain_active?

    assistant = conversation.inbox.captain_assistant
    return unless assistant

    Captain::Llm::ContactNotesService.new(assistant, conversation).generate_and_update_notes if assistant.config['feature_memory'].present?
    Captain::Llm::ConversationFaqService.new(assistant, conversation).generate_and_deduplicate if assistant.config['feature_faq'].present?
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end
