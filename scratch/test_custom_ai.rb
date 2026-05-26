# frozen_string_literal: true

# Load Rails Environment
require_relative '../config/environment'

puts "=================================================="
puts "🧪 Chatwoot Custom AI Chatbot Test Utility"
puts "=================================================="

# 1. Ensure we have mock data
account = Account.first || Account.create!(name: "Test AI Account")
inbox = Inbox.first || Inbox.create!(
  name: "Test Live Chat",
  account: account,
  channel: Channel::WebWidget.create!(account: account, website_url: "https://test.com")
)
contact = Contact.first || Contact.create!(
  name: "John Doe",
  account: account
)
contact_inbox = ContactInbox.first || ContactInbox.create!(
  contact: contact,
  inbox: inbox,
  source_id: "test-source-id"
)
conversation = Conversation.first || Conversation.create!(
  account: account,
  inbox: inbox,
  contact: contact,
  contact_inbox: contact_inbox,
  status: :open
)

# 2. Add an incoming message from the customer
customer_message = conversation.messages.create!(
  account: account,
  inbox: inbox,
  message_type: :incoming,
  content: "Hello! What are your business hours and where are you located?",
  private: false,
  sender: contact
)

puts "\n[+] Step 1: Simulated Customer Message Created:"
puts "    - Customer: #{contact.name}"
puts "    - Message: \"#{customer_message.content}\""
puts "    - Conversation ID: #{conversation.display_id}"

# 3. Ask user if they want to mock the API response or call real OpenAI
puts "\n[+] Step 2: Running Custom AI Reply Job..."
api_key = ENV['CUSTOM_AI_API_KEY'] || ENV['OPENAI_API_KEY']

if api_key.blank?
  puts "    [!] No API Key found in ENV. Mocking LLM API Response for testing..."
  
  # Mock the network call in CustomAiReplyJob
  CustomAiReplyJob.class_eval do
    alias_method :original_call_llm_api, :call_llm_api
    
    def call_llm_api(endpoint_url, api_key, model_name, messages_payload)
      puts "    [Mock] Simulating LLM response using gpt-4o-mini..."
      "Hello John! Our business hours are Monday to Friday, 9 AM to 5 PM. We are located in Cairo, Egypt."
    end
  end
else
  puts "    [*] API Key detected. Performing real LLM request to: #{ENV.fetch('CUSTOM_AI_MODEL', 'gpt-4o-mini')}"
end

# 4. Perform the job synchronously
begin
  CustomAiReplyJob.perform_now(customer_message.id)
  
  # Retrieve the latest outgoing message
  reply_message = conversation.messages.where(message_type: :outgoing).last
  
  puts "\n[+] Step 3: Job Execution Completed Successfully!"
  if reply_message
    puts "    - Bot Reply: \"#{reply_message.content}\""
    puts "    - Sent by: #{reply_message.sender_type || 'System/Bot'}"
    puts "    - Private Note: #{reply_message.private}"
  else
    puts "    [!] Error: No reply message was created in the database."
  end
rescue => e
  puts "\n    [!] Error during execution: #{e.message}"
  puts e.backtrace.first(5).join("\n")
ensure
  # Restore original method if we mocked it
  if api_key.blank?
    CustomAiReplyJob.class_eval do
      alias_method :call_llm_api, :original_call_llm_api rescue nil
    end
  end
end

puts "\n=================================================="
puts "🧪 Test Finished!"
puts "=================================================="
