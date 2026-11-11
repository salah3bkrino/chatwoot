class Whatsapp::IncomingMessageEvolutionService
  MEDIA_NODES = {
    imageMessage: { file_type: :image, mime: 'image/jpeg', ext: 'jpg' },
    stickerMessage: { file_type: :image, mime: 'image/webp', ext: 'webp' },
    videoMessage: { file_type: :video, mime: 'video/mp4', ext: 'mp4' },
    audioMessage: { file_type: :audio, mime: 'audio/ogg', ext: 'ogg' },
    documentMessage: { file_type: :file, mime: 'application/octet-stream', ext: 'bin' }
  }.freeze
  WRAPPER_KEYS = %i[ephemeralMessage viewOnceMessage viewOnceMessageV2 documentWithCaptionMessage editedMessage].freeze
  MIME_EXTENSIONS = {
    'image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp',
    'audio/ogg' => 'ogg', 'audio/mpeg' => 'mp3', 'audio/mp4' => 'm4a',
    'video/mp4' => 'mp4', 'application/pdf' => 'pdf'
  }.freeze

  pattr_initialize [:inbox!, :params!]

  def perform
    @indifferent_params = params.with_indifferent_access
    event = @indifferent_params[:event].to_s.downcase.tr('_', '.')
    return update_connection_health if event == 'connection.update'
    return unless event == 'messages.upsert'

    extract_items(@indifferent_params[:data]).each { |item| process_item(item) }
  end

  private

  def update_connection_health
    state = @indifferent_params.dig(:data, :state)
    return if state.blank?

    health = (inbox.channel.phone_number_health || {}).merge('evolution_state' => state, 'updated_at' => Time.current.iso8601)
    # rubocop:disable Rails/SkipsModelValidations
    inbox.channel.update_columns(phone_number_health: health, phone_number_health_checked_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def extract_items(data)
    return data if data.is_a?(Array)
    return data[:messages] if data.is_a?(Hash) && data[:messages].is_a?(Array)

    data.is_a?(Hash) ? [data] : []
  end

  def process_item(raw_item)
    item = raw_item.with_indifferent_access
    key = item[:key] || {}
    msg_id = key[:id].to_s
    digits = extract_digits(key)
    return if msg_id.blank? || digits.blank?
    return if Message.exists?(source_id: msg_id) || !Whatsapp::MessageDedupLock.new(msg_id).acquire!

    outgoing_echo = ActiveModel::Type::Boolean.new.cast(key[:fromMe]) == true
    set_contact(digits, outgoing_echo ? nil : item[:pushName].presence)
    return if @contact.blank? || (@contact.blocked? && !outgoing_echo)

    persist_message(item, msg_id, outgoing_echo)
  end

  def extract_digits(key)
    remote_jid = key[:remoteJid].to_s
    return nil if remote_jid.blank? || remote_jid.end_with?('@g.us', '@broadcast', '@newsletter') || remote_jid == 'status@broadcast'

    phone_jid = remote_jid.end_with?('@lid') && key[:remoteJidAlt].present? ? key[:remoteJidAlt].to_s : remote_jid
    phone_jid.split('@').first.to_s.delete('^0-9').presence
  end

  def set_contact(digits, push_name)
    formatted_phone = "+#{digits}"
    normalizer = Whatsapp::PhoneNumberNormalizationService.new(inbox)
    source_id = normalizer.normalize_and_find_contact_by_provider(digits, :cloud)
    candidates = normalizer.phone_number_candidates(digits).drop(1).map { |num| "+#{num}" }
    @contact_inbox = ContactInboxWithContactBuilder.new(
      source_id: source_id,
      inbox: inbox,
      contact_attributes: { name: push_name || formatted_phone, phone_number: formatted_phone, phone_number_candidates: candidates.presence }.compact
    ).perform
    @contact = @contact_inbox.contact
    @contact.update!(name: push_name) if push_name.present? && @contact.name == formatted_phone
  end

  def persist_message(item, msg_id, outgoing_echo)
    ActiveRecord::Base.transaction do
      set_conversation
      msg_payload = unwrap_message(item[:message])
      build_message(item, msg_payload, msg_id, outgoing_echo)
      attach_media_or_location(item, msg_payload, msg_id)
      @message.save! if @message.content.present? || @message.attachments.present?
    end
  end

  def set_conversation
    conversations = @contact_inbox.conversations
    @conversation = if inbox.lock_to_single_conversation
                      conversations.last
                    else
                      conversations.where.not(status: :resolved).last
                    end
    @conversation ||= ::Conversation.create!(
      account_id: inbox.account_id, inbox_id: inbox.id, contact_id: @contact.id, contact_inbox_id: @contact_inbox.id
    )
  end

  def unwrap_message(raw_msg)
    msg = raw_msg.is_a?(Hash) ? raw_msg : {}
    2.times do
      wrapper = WRAPPER_KEYS.find { |key| msg.dig(key, :message).is_a?(Hash) }
      break unless wrapper

      msg = msg.dig(wrapper, :message)
    end
    msg
  end

  def build_message(item, msg_payload, msg_id, outgoing_echo)
    attrs = outgoing_echo ? { external_echo: true } : {}
    apply_reply_context(attrs, item, msg_payload)
    @message = @conversation.messages.build(
      content: extract_text(msg_payload),
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: outgoing_echo ? :outgoing : :incoming,
      status: outgoing_echo ? :delivered : :sent,
      sender: outgoing_echo ? nil : @contact,
      source_id: msg_id,
      content_attributes: attrs
    )
  end

  def apply_reply_context(attrs, item, msg_payload)
    quoted_id = item.dig(:contextInfo, :stanzaId) || msg_payload.dig(:extendedTextMessage, :contextInfo, :stanzaId)
    return if quoted_id.blank?

    attrs[:in_reply_to_external_id] = quoted_id
    reply_msg = Whatsapp::InReplyToMessageFinder.new(conversation: @conversation, source_id: quoted_id).perform
    attrs[:in_reply_to] = reply_msg.id if reply_msg
  end

  def extract_text(msg)
    msg[:conversation] ||
      msg.dig(:extendedTextMessage, :text) ||
      msg.dig(:buttonsResponseMessage, :selectedDisplayText) ||
      msg.dig(:listResponseMessage, :title) ||
      msg.dig(:templateButtonReplyMessage, :selectedDisplayText) ||
      extract_caption(msg)
  end

  def extract_caption(msg)
    msg.dig(:imageMessage, :caption) || msg.dig(:videoMessage, :caption) || msg.dig(:documentMessage, :caption)
  end

  def attach_media_or_location(item, msg_payload, msg_id)
    location = msg_payload[:locationMessage] || msg_payload[:liveLocationMessage]
    return attach_location(location) if location.present?

    media_key = MEDIA_NODES.keys.find { |key| msg_payload[key].is_a?(Hash) }
    return unless media_key

    attach_base64_media(item, msg_payload[media_key], media_key, msg_id)
  end

  def attach_location(location)
    title = [location[:name], location[:address]].compact_blank.join(', ').first(255)
    @message.attachments.new(
      account_id: inbox.account_id, file_type: :location,
      coordinates_lat: location[:degreesLatitude], coordinates_long: location[:degreesLongitude], fallback_title: title
    )
  end

  def attach_base64_media(item, node, media_key, msg_id)
    raw_base64 = extract_base64_payload(item, node)
    return if raw_base64.blank?

    meta_info = MEDIA_NODES[media_key]
    mime = (node[:mimetype].presence || meta_info[:mime]).to_s.split(';').first.strip
    decoded = Base64.decode64(raw_base64.to_s.sub(/\Adata:[^;]+;base64,/, ''))
    filename = node[:fileName].presence || "media_#{msg_id}.#{MIME_EXTENSIONS[mime] || meta_info[:ext]}"
    attrs = {
      account_id: inbox.account_id,
      file_type: meta_info[:file_type],
      file: { io: StringIO.new(decoded), filename: filename, content_type: mime }
    }
    attrs[:meta] = { is_voice_message: true } if media_key == :audioMessage && node[:ptt] == true
    @message.attachments.new(attrs)
  end

  def extract_base64_payload(item, node)
    item.dig(:message, :base64).presence ||
      @indifferent_params.dig(:data, :message, :base64).presence ||
      item[:base64].presence ||
      node[:base64].presence
  end
end
