# frozen_string_literal: true

class CustomAiListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]

    return if ignore_message?(message)

    CustomAiReplyJob.perform_later(message.id)
  end

  private

  def ignore_message?(message)
    # Ignore if not an incoming message (customer message)
    return true unless message.incoming?

    # Ignore if it is a private note
    return true if message.private?

    # Ignore if it's a system or activity message
    return true if message.activity?

    # Ignore if message has no content
    return true if message.content.blank?

    # Ignore if conversation is already resolved or snoozed (optional, but good for happy path)
    return true if message.conversation.resolved?

    false
  end
end
