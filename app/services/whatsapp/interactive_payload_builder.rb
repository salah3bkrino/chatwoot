class Whatsapp::InteractivePayloadBuilder
  def initialize(message)
    @message = message
  end

  def build
    case config['type'].to_s
    when 'flow'
      build_flow_payload
    when 'location_request_message'
      build_location_request_payload
    when 'cta_url'
      build_cta_url_payload
    when 'product'
      build_product_payload
    when 'product_list'
      build_product_list_payload
    else
      raise ArgumentError, "Unsupported interactive type: #{config['type']}"
    end
  end

  private

  def config
    @config ||= begin
      raw_attrs = (@message.content_attributes || {}).with_indifferent_access
      interactive = raw_attrs['whatsapp_interactive']
      interactive.is_a?(Hash) ? interactive.with_indifferent_access : {}.with_indifferent_access
    end
  end

  def build_flow_payload
    require_fields!('flow_id', 'flow_cta')
    {
      type: 'flow',
      header: build_header,
      body: { text: body_text.to_s },
      footer: build_footer,
      action: { name: 'flow', parameters: flow_parameters }
    }.compact
  end

  def flow_parameters
    cfg = config
    {
      flow_message_version: (cfg['flow_message_version'].presence || '3').to_s,
      flow_token: cfg['flow_token'].presence&.to_s || default_flow_token,
      flow_id: cfg['flow_id'].to_s,
      flow_cta: cfg['flow_cta'].to_s,
      flow_action: (cfg['flow_action'].presence || 'navigate').to_s,
      flow_action_payload: build_flow_action_payload(cfg)
    }.compact
  end

  def default_flow_token
    "cw_#{@message.conversation_id}_#{@message.id || SecureRandom.hex(4)}"
  end

  def build_flow_action_payload(flow_config)
    explicit = flow_config['flow_action_payload']
    return explicit.symbolize_keys.compact.presence if explicit.is_a?(Hash) && explicit.present?
    return nil if flow_config['flow_action'].to_s == 'data_exchange'

    { screen: flow_config['screen'].presence, data: flow_config['data'].presence }.compact.presence
  end

  def build_location_request_payload
    {
      type: 'location_request_message',
      body: { text: body_text('Please share your location').to_s },
      action: { name: 'send_location' }
    }
  end

  def build_cta_url_payload
    require_fields!('display_text', 'url')
    {
      type: 'cta_url',
      header: build_header,
      body: { text: body_text.to_s },
      footer: build_footer,
      action: {
        name: 'cta_url',
        parameters: { display_text: config['display_text'].to_s, url: config['url'].to_s }
      }
    }.compact
  end

  def build_product_payload
    require_fields!('catalog_id', 'product_retailer_id')
    text = body_text
    {
      type: 'product',
      body: text.present? ? { text: text } : nil,
      footer: build_footer,
      action: {
        catalog_id: config['catalog_id'].to_s,
        product_retailer_id: config['product_retailer_id'].to_s
      }
    }.compact
  end

  def build_product_list_payload
    require_fields!('catalog_id', 'header', 'sections')
    raise ArgumentError, 'sections must be an array' unless config['sections'].is_a?(Array)

    header = build_text_header
    raise ArgumentError, 'header text is required for product_list' if header.blank?

    {
      type: 'product_list',
      header: header,
      body: { text: body_text.to_s },
      footer: build_footer,
      action: {
        catalog_id: config['catalog_id'].to_s,
        sections: normalize_product_sections(config['sections'])
      }
    }.compact
  end

  def normalize_product_sections(sections)
    sections.map do |raw_section|
      raise ArgumentError, 'Each product_list section must be a hash' unless raw_section.is_a?(Hash)

      section = raw_section.with_indifferent_access
      items = normalize_product_items(section['product_items'] || section['items'])
      raise ArgumentError, 'Each product_list section must include product_items' if items.empty?

      { title: section['title'].presence&.to_s, product_items: items }.compact
    end
  end

  def normalize_product_items(raw_items)
    Array(raw_items).filter_map do |item|
      retailer_id = if item.is_a?(Hash)
                      item.with_indifferent_access.values_at('product_retailer_id', 'retailer_id', 'id').find(&:present?)
                    else
                      item
                    end
      next if retailer_id.blank?

      { product_retailer_id: retailer_id.to_s }
    end
  end

  def body_text(fallback = nil)
    raw_body = config['body'].is_a?(Hash) ? config.dig('body', 'text') : (config['body'].presence || config['body_text'])
    (raw_body.presence || @message.outgoing_content.presence || fallback)&.to_s
  end

  def build_header
    header = config['header']
    return if header.blank?
    return header.deep_symbolize_keys if header.is_a?(Hash) && header['type'].present? && header['type'].to_s != 'text'

    build_text_header
  end

  def build_text_header
    text = extract_text(config['header'])
    { type: 'text', text: text } if text.present?
  end

  def build_footer
    text = extract_text(config['footer'])
    { text: text } if text.present?
  end

  def extract_text(value)
    return if value.blank?

    text = value.is_a?(Hash) ? value['text'] : value
    text.presence&.to_s
  end

  def require_fields!(*fields)
    missing = fields.select { |field| config[field].blank? }
    return if missing.empty?

    raise ArgumentError, "Missing required fields for #{config['type']}: #{missing.join(', ')}"
  end
end
