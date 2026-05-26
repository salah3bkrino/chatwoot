# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class CustomAiReplyJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return if message.blank?

    conversation = message.conversation
    return if conversation.blank?

    # Prevent replying if the customer message is not the latest message anymore
    return unless conversation.messages.last.id == message.id

    # Retrieve API Configuration
    api_key = ENV.fetch('CUSTOM_AI_API_KEY', nil) ||
              ENV.fetch('OPENAI_API_KEY', nil) ||
              InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value

    if api_key.blank?
      Rails.logger.warn "[CustomAiReplyJob] Skipped: No API Key configured (Set CUSTOM_AI_API_KEY or OPENAI_API_KEY)"
      return
    end

    api_endpoint = ENV.fetch('CUSTOM_AI_API_ENDPOINT', 'https://api.openai.com/v1/chat/completions')
    api_model = ENV.fetch('CUSTOM_AI_MODEL', 'gpt-4o-mini')

    # Format the prompt and context history
    messages_payload = format_conversation_history(conversation)

    # Call AI API
    ai_response = call_llm_api(api_endpoint, api_key, api_model, messages_payload)
    return if ai_response.blank?

    # Send the generated reply back to the conversation
    send_reply(conversation, ai_response)
  end

  private

  def format_conversation_history(conversation)
    system_prompt = <<~SYSTEM
      You are a professional and extremely helpful customer support agent.
      Answer the user's questions clearly, politely, and concisely.
      Keep answers short and directly to the point.
    SYSTEM

    # Fetch recent non-activity, public messages
    recent_messages = conversation.messages
                                  .where.not(message_type: :activity)
                                  .where(private: false)
                                  .order(created_at: :asc)
                                  .last(10)

    payload = [{ role: 'system', content: system_prompt }]

    recent_messages.each do |msg|
      role = msg.incoming? ? 'user' : 'assistant'
      payload << { role: role, content: msg.content }
    end

    payload
  end

  def call_llm_api(endpoint_url, api_key, model_name, messages_payload)
    uri = URI.parse(endpoint_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.read_timeout = 30 # seconds

    request = Net::HTTP::Post.new(uri.path.empty? ? '/' : uri.path)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{api_key}"

    body = {
      model: model_name,
      messages: messages_payload,
      temperature: 0.7
    }

    request.body = body.to_json

    response = http.request(request)

    if response.code.to_i == 200
      result = JSON.parse(response.body)
      result.dig('choices', 0, 'message', 'content')&.strip
    else
      Rails.logger.error "[CustomAiReplyJob] LLM API returned error code #{response.code}: #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "[CustomAiReplyJob] LLM Request failed: #{e.message}"
    nil
  end

  def send_reply(conversation, reply_content)
    params = {
      content: reply_content,
      private: false,
      message_type: 'outgoing'
    }

    # Use the native Chatwoot MessageBuilder to save and broadcast the message
    Messages::MessageBuilder.new(nil, conversation, params).perform
  end
end
