class Whatsapp::Providers::EvolutionService < Whatsapp::Providers::BaseService
  WEBHOOK_EVENTS = %w[MESSAGES_UPSERT CONNECTION_UPDATE QRCODE_UPDATED].freeze
  MEDIA_TYPES = %w[image video audio].freeze
  DEFAULT_API_URL = 'http://localhost:32768'.freeze

  def api_url = (config['api_url'].presence || ENV.fetch('EVOLUTION_API_URL', DEFAULT_API_URL)).to_s.strip.chomp('/')
  def api_key = config['api_key'].presence || ENV.fetch('EVOLUTION_API_KEY', nil)
  def instance_name = config['instance_name'].presence || "atmta_#{whatsapp_channel.account_id}_#{whatsapp_channel.phone_number.to_s.delete('^0-9')}"
  def api_headers = { 'apikey' => api_key.to_s, 'Content-Type' => 'application/json' }
  def sync_templates = []
  def media_url(_media_id) = nil

  def validate_provider_config?
    uri = URI.parse(api_url)
    uri.is_a?(URI::HTTP) && uri.host.present? && api_key.present? && instance_name.present?
  rescue URI::InvalidURIError
    false
  end

  def setup_instance
    payload = { instanceName: instance_name, qrcode: true, integration: 'WHATSAPP-BAILEYS', webhook: webhook_payload }
    response = request_json(:post, '/instance/create', payload)
    return parsed_hash(response) if response.success?
    raise "Evolution API setup failed (#{response.code}): #{extract_error(response)}" unless already_in_use_response?(response)

    request_json(:post, "/webhook/set/#{instance_name}", { webhook: webhook_payload.merge(enabled: true) })
    { instance_name: instance_name, webhook_updated: true }
  end

  def fetch_qr_code
    setup_instance if request_json(:get, "/instance/connectionState/#{instance_name}").code == 404
    response = request_json(:get, "/instance/connect/#{instance_name}")
    if response.code == 404
      setup_instance
      response = request_json(:get, "/instance/connect/#{instance_name}")
    end
    normalize_qr_response(parsed_hash(checked_response(response, 'QR fetch')))
  end

  def connection_status
    response = request_json(:get, "/instance/connectionState/#{instance_name}")
    return { state: 'close', instance_name: instance_name } if response.code == 404

    { state: parsed_state(checked_response(response, 'status check'), 'close'), instance_name: instance_name }
  end

  def restart_instance
    response = checked_response(request_json(:post, "/instance/restart/#{instance_name}"), 'restart')
    { success: true, state: parsed_state(response, 'connecting'), instance_name: instance_name }
  end

  def logout_instance
    response = request_json(:delete, "/instance/logout/#{instance_name}")
    checked_response(response, 'logout') unless response.code == 404
    { success: true, state: 'close', instance_name: instance_name }
  end

  def delete_instance
    request_json(:delete, "/instance/delete/#{instance_name}")
  rescue StandardError => e
    Rails.logger.warn "[EVOLUTION] Failed to delete instance #{instance_name}: #{e.message}"
    nil
  end

  def send_template(phone_number, _template_info, message)
    return nil if message.blank?

    send_message(phone_number, message)
  end

  def send_message(phone_number, message)
    number = phone_number.to_s.delete('^0-9')
    return handle_evolution_error('Invalid recipient phone number', message) if number.blank?

    if message.attachments.present?
      send_attachment_message(number, message)
    elsif interactive_message?(message)
      send_text_payload(number, format_interactive_text(message), message)
    else
      send_text_payload(number, message.outgoing_content.to_s, message)
    end
  rescue StandardError => e
    handle_evolution_error(e.message, message)
  end

  private

  def config = whatsapp_channel.provider_config || {}

  def webhook_callback_url
    base_url = ENV.fetch('FRONTEND_URL', 'http://localhost:3000').to_s.chomp('/')
    url = "#{base_url}/webhooks/whatsapp/#{whatsapp_channel.phone_number}"
    token = config['webhook_verify_token']
    token.present? ? "#{url}?token=#{ERB::Util.url_encode(token)}" : url
  end

  def webhook_payload
    { url: webhook_callback_url, byEvents: false, base64: true, events: WEBHOOK_EVENTS }
  end

  def already_in_use_response?(response)
    [403, 409].include?(response.code) || response.body.to_s.match?(/already\s+(in\s+use|exists)/i)
  end

  def normalize_qr_response(parsed)
    qr = parsed['qrcode'].is_a?(Hash) ? parsed['qrcode'] : parsed
    raw_b64 = qr['base64']
    base64 = raw_b64.present? && !raw_b64.start_with?('data:image') ? "data:image/png;base64,#{raw_b64}" : raw_b64.presence
    state = parsed.dig('instance', 'state') || parsed['state'] || (base64.present? ? 'connecting' : 'close')
    { state: state, base64: base64, code: qr['code'], pairing_code: qr['pairingCode'] || qr['pairing_code'], instance_name: instance_name }
  end

  def send_text_payload(number, text, message)
    process_evolution_response(request_json(:post, "/message/sendText/#{instance_name}", { number: number, text: text, delay: 800 }), message)
  end

  def send_attachment_message(number, message)
    attachment = message.attachments.first
    url = attachment.download_url
    return handle_evolution_error('Attachment URL missing', message) if url.blank?

    response = if attachment.file_type == 'audio' && attachment.meta&.dig('is_voice_message').present?
                 request_json(:post, "/message/sendWhatsAppAudio/#{instance_name}", { number: number, audio: url, delay: 800 })
               else
                 request_json(:post, "/message/sendMedia/#{instance_name}", media_payload(number, attachment, url, message.outgoing_content.to_s))
               end
    process_evolution_response(response, message)
  end

  def media_payload(number, attachment, url, caption)
    mediatype = MEDIA_TYPES.include?(attachment.file_type) ? attachment.file_type : 'document'
    mimetype = attachment.file&.content_type.presence || 'application/octet-stream'
    { number: number, mediatype: mediatype, mimetype: mimetype, media: url, caption: caption, fileName: attachment.file&.filename&.to_s }.compact
  end

  def interactive_message?(message)
    message.content_type == 'input_select' || message.content_attributes['whatsapp_interactive'].present?
  end

  def format_interactive_text(message)
    interactive = (message.content_attributes['whatsapp_interactive'] || {}).with_indifferent_access
    body = extract_text_node(interactive[:body]) || interactive[:body_text] || message.outgoing_content.to_s
    options = extract_interactive_options(message, interactive)
    options_text = options.each_with_index.map { |opt, idx| "#{idx + 1}. #{opt}" }.join("\n") if options.present?
    cta_line = format_cta_line(interactive)
    [extract_text_node(interactive[:header]), body, options_text, cta_line, extract_text_node(interactive[:footer])].compact_blank.join("\n\n")
  end

  def extract_text_node(value)
    return nil if value.blank?

    (value.is_a?(Hash) ? value[:text] || value['text'] : value).to_s.presence
  end

  def format_cta_line(interactive)
    url = interactive[:url] || interactive.dig(:action, :url)
    label = interactive[:display_text] || interactive[:flow_cta]
    return "#{label}: #{url}" if label.present? && url.present?

    url.presence || label.presence
  end

  def extract_interactive_options(message, interactive)
    items = Array(message.content_attributes['items'])
    buttons = Array(interactive[:buttons])
    rows = Array(interactive[:sections]).flat_map { |sec| Array(sec[:rows] || sec['rows'] || sec[:product_items] || sec['product_items']) }
    (items + buttons + rows).filter_map do |raw|
      next raw.to_s if raw.is_a?(String)

      item = raw.with_indifferent_access
      item['title'] || item.dig('reply', 'title') || item['display_text'] || item['product_retailer_id']
    end
  end

  def request_json(method, path, body = nil)
    options = { headers: api_headers, timeout: 15 }
    options[:body] = body.to_json if body.present?
    HTTParty.public_send(method, "#{api_url}#{path}", options)
  end

  def checked_response(response, action)
    raise "Evolution #{action} failed (#{response.code}): #{extract_error(response)}" unless response.success?

    response
  end

  def parsed_state(response, default)
    parsed = parsed_hash(response)
    parsed.dig('instance', 'state') || parsed['state'] || default
  end

  def parsed_hash(response) = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}

  def extract_error(response)
    parsed = parsed_hash(response)
    parsed['message'] || parsed['error'] || parsed.dig('response', 'message') || response.body.to_s.truncate(200)
  end

  def process_evolution_response(response, message)
    return handle_evolution_error(extract_error(response), message) unless response.success?

    parsed = parsed_hash(response)
    parsed.dig('key', 'id') || parsed['id'] || parsed.dig('message', 'key', 'id')
  end

  def handle_evolution_error(error_msg, message)
    Rails.logger.error "[EVOLUTION] #{error_msg}"
    message.update!(status: :failed, external_error: error_msg.to_s.truncate(255)) if message.present?
    nil
  end
end
