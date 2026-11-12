class Whatsapp::FlowsService
  API_VERSION = 'v22.0'.freeze
  TIMEOUT_SECONDS = 8

  def initialize(whatsapp_channel)
    @channel = whatsapp_channel
  end

  def list
    return [] unless valid_cloud_channel?

    response = HTTParty.get(
      flows_url,
      query: { fields: 'id,name,status,categories' },
      headers: { 'Authorization' => "Bearer #{access_token}" },
      timeout: TIMEOUT_SECONDS
    )
    return parse_flows(response) if response.success?

    Rails.logger.warn("[WHATSAPP FLOWS] Failed to fetch flows for inbox #{@channel.inbox&.id}: #{response.code}")
    []
  rescue StandardError => e
    Rails.logger.warn("[WHATSAPP FLOWS] Error fetching flows for inbox #{@channel.inbox&.id}: #{e.message}")
    []
  end

  private

  def valid_cloud_channel?
    @channel.is_a?(Channel::Whatsapp) &&
      @channel.provider == 'whatsapp_cloud' &&
      business_account_id.present? &&
      access_token.present?
  end

  def business_account_id
    @channel.provider_config['business_account_id']
  end

  def access_token
    @channel.template_access_token
  end

  def flows_url
    base_url = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
    "#{base_url}/#{API_VERSION}/#{business_account_id}/flows"
  end

  def parse_flows(response)
    data = response.parsed_response.is_a?(Hash) ? response.parsed_response['data'] : nil
    Array(data).filter_map do |flow|
      next unless flow.is_a?(Hash) && flow['id'].present?

      {
        id: flow['id'].to_s,
        name: flow['name'].to_s,
        status: flow['status'].to_s,
        categories: Array(flow['categories'])
      }
    end
  end
end
