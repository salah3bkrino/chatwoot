class Whatsapp::OneoffCampaignService
  pattr_initialize [:campaign!]

  BATCH_SIZE = 100
  MAX_BATCH_DELAY_SECONDS = 300
  MAX_MESSAGE_JITTER_MS = 2000

  def perform
    validate_campaign!
    Campaigns::SendWhatsappBatchJob.perform_later(campaign)
  end

  def perform_batch(cursor)
    return pause_for_risky_health if channel_health_risky?

    limit = effective_batch_size
    contacts = audience_contacts.where('contacts.id > ?', cursor).order(:id).limit(limit).to_a
    process_contacts(contacts)
    contacts.last.id if contacts.size == limit && !channel_health_risky?
  end

  def anti_ban_config
    config = campaign.template_params&.then { |tp| tp.is_a?(Hash) ? (tp['anti_ban'] || tp[:anti_ban]) : nil }
    config.is_a?(Hash) ? config.stringify_keys : {}
  end

  def effective_batch_size = anti_ban_enabled? ? anti_ban_int('batch_size', 25).clamp(5, BATCH_SIZE) : BATCH_SIZE

  def per_message_jitter_ms = anti_ban_enabled? ? anti_ban_int('per_message_jitter_ms', 400).clamp(0, MAX_MESSAGE_JITTER_MS) : 0

  def next_batch_delay_seconds
    return 0 unless anti_ban_enabled?

    min_delay = anti_ban_int('min_delay_seconds', 15).clamp(0, MAX_BATCH_DELAY_SECONDS)
    max_delay = anti_ban_int('max_delay_seconds', 45).clamp(min_delay, MAX_BATCH_DELAY_SECONDS)
    rand(min_delay..max_delay)
  end

  def channel_health_risky?
    return false unless pause_on_risky_health?

    health = channel&.phone_number_health.to_h.stringify_keys
    return false if health.empty?

    Whatsapp::HealthService::RISKY_STATUSES.include?(health['status']) || health['quality_rating'] == 'RED'
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def validate_campaign_type!
    raise "Invalid campaign #{campaign.id}" unless whatsapp_campaign? && campaign.one_off?
  end

  def whatsapp_campaign?
    campaign.inbox.inbox_type == 'Whatsapp'
  end

  def validate_campaign_status!
    raise 'Completed Campaign' if campaign.completed?
  end

  def validate_provider!
    raise 'WhatsApp Cloud provider required' unless whatsapp_cloud_channel?
  end

  def validate_feature_flag!
    raise 'WhatsApp campaigns feature not enabled' unless campaign.account.feature_enabled?(:campaigns)
  end

  def validate_campaign!
    validate_campaign_type!
    validate_campaign_status!
    validate_provider!
    validate_feature_flag!
  end

  def extract_audience_labels
    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    campaign.account.labels.where(id: audience_label_ids).pluck(:title)
  end

  def process_contact(contact)
    Rails.logger.info "Processing contact: #{contact.name} (#{contact.phone_number})"

    recipient, recipient_error = campaign_destination(contact)
    if recipient.blank?
      Rails.logger.warn "Skipping campaign recipient contact_id=#{contact.id}: #{recipient_error}"
      return
    end

    if campaign.template_params.blank?
      Rails.logger.error "Skipping contact #{contact.name} - no template_params found for WhatsApp campaign"
      return
    end

    processed_template_params = process_liquid_template_params(contact)
    return if processed_template_params.nil?

    send_whatsapp_template_message(to: recipient, template_params: processed_template_params)
  end

  def audience_contacts
    campaign.account.contacts.tagged_with(extract_audience_labels, any: true)
  end

  def process_contacts(contacts)
    contacts.each do |contact|
      return pause_for_risky_health if channel_health_risky?

      process_contact(contact)
      apply_per_message_jitter
    end
  end

  def anti_ban_bool(key, default: false)
    anti_ban_config.key?(key) ? ActiveModel::Type::Boolean.new.cast(anti_ban_config[key]) == true : default
  end

  def anti_ban_enabled? = anti_ban_bool('enabled')

  def pause_on_risky_health? = anti_ban_bool('pause_on_risky_health', default: anti_ban_enabled?)

  def anti_ban_int(key, default) = anti_ban_config[key].presence&.to_i || default

  def apply_per_message_jitter
    jitter_ms = per_message_jitter_ms
    return unless jitter_ms.positive?

    delay = [rand(0..jitter_ms) / 1000.0, 2.0].min
    sleep(delay) if delay.positive?
  end

  def pause_for_risky_health
    Rails.logger.warn "[ANTI-BAN] Pausing campaign #{campaign.id}: risky WhatsApp channel health"
    nil
  end

  def process_liquid_template_params(contact)
    liquid_processor = Whatsapp::LiquidTemplateProcessorService.new(campaign: campaign, contact: contact)
    processed_template_params = liquid_processor.process_template_params(campaign.template_params)

    Rails.logger.info "Skipping contact #{contact.name} - liquid variables resolved to blank values" if processed_template_params.nil?

    processed_template_params
  rescue StandardError => e
    Rails.logger.error "Failed to process liquid template params for contact #{contact.name}: #{e.message}"
    nil
  end

  def send_whatsapp_template_message(to:, template_params:)
    return if authentication_template_blocked?(to, template_params)

    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: template_params
    )

    name, namespace, lang_code, processed_parameters = processor.call

    return if name.blank?

    channel.send_template(to, {
                            name: name,
                            namespace: namespace,
                            lang_code: lang_code,
                            parameters: processed_parameters
                          }, nil)

  rescue StandardError => e
    Rails.logger.error "Failed to send WhatsApp template message to #{to}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
    # continue processing remaining contacts
    nil
  end

  def authentication_template_blocked?(recipient, params)
    error = Whatsapp::AuthenticationTemplateGuard.new(channel: channel, recipient: recipient, template_params: params).error
    return false unless error

    Rails.logger.warn "Skipping BSUID campaign recipient: #{error}"
    true
  end

  def campaign_destination(contact)
    return [contact.phone_number, nil] if contact.phone_number.present?

    bsuid_contact_inboxes = bsuid_contact_inboxes_for(contact)
    return [nil, 'Phone number and BSUID are missing'] if bsuid_contact_inboxes.empty?

    bsuid_recipient = preferred_bsuid_recipient(bsuid_contact_inboxes)
    return [bsuid_recipient, nil] if bsuid_recipient.present?

    [nil, 'Multiple WhatsApp identities found; refusing to choose a destination']
  end

  def bsuid_contact_inboxes_for(contact)
    contact.contact_inboxes.where(inbox_id: inbox.id).select do |contact_inbox|
      bsuid_source_id?(contact_inbox.source_id)
    end
  end

  def preferred_bsuid_recipient(contact_inboxes)
    return contact_inboxes.first.source_id if contact_inboxes.one?
  end

  def bsuid_source_id?(source_id)
    source_id.to_s.delete_prefix('whatsapp:').match?(RegexHelper::WHATSAPP_BSUID_REGEX)
  end

  def whatsapp_cloud_channel?
    channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud'
  end
end

Whatsapp::OneoffCampaignService.prepend_mod_with('Whatsapp::OneoffCampaignService')
