class Campaigns::SendWhatsappBatchJob < ApplicationJob
  queue_as :low

  LOCK_TIMEOUT = 15.minutes

  def perform(campaign, cursor = 0)
    key = format(Redis::Alfred::WHATSAPP_CAMPAIGN_MUTEX, campaign_id: campaign.id)
    Redis::LockManager.new.with_lock(key, LOCK_TIMEOUT) do
      send_batch(campaign.reload, cursor)
    end
  end

  private

  def send_batch(campaign, cursor)
    return if campaign.completed?

    service = Whatsapp::OneoffCampaignService.new(campaign: campaign)
    return log_health_pause(campaign) if service.try(:channel_health_risky?)

    next_cursor = service.perform_batch(cursor)
    return log_health_pause(campaign) if service.try(:channel_health_risky?)

    if next_cursor
      enqueue_next_batch(campaign, next_cursor, service.try(:next_batch_delay_seconds).to_i)
    else
      campaign.with_lock { campaign.completed! unless campaign.completed? }
    end
  end

  def enqueue_next_batch(campaign, next_cursor, delay_seconds)
    if delay_seconds.positive?
      self.class.set(wait: delay_seconds.seconds).perform_later(campaign, next_cursor)
    else
      self.class.perform_later(campaign, next_cursor)
    end
  end

  def log_health_pause(campaign)
    Rails.logger.warn "[ANTI-BAN] Pausing campaign #{campaign.id}: risky WhatsApp channel health"
  end
end
