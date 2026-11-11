module Api::V1::Accounts::Concerns::EvolutionWhatsappManagement
  extend ActiveSupport::Concern

  EVOLUTION_ACTIONS = [:evolution_qr, :evolution_status, :evolution_reconnect, :evolution_disconnect].freeze

  included do
    skip_before_action :check_authorization, only: EVOLUTION_ACTIONS
    before_action :validate_evolution_channel, only: EVOLUTION_ACTIONS
  end

  def evolution_qr
    authorize @inbox, :update?
    render_evolution_action { @inbox.channel.provider_service.fetch_qr_code }
  end

  def evolution_status
    authorize @inbox, :show?
    render_evolution_action { @inbox.channel.provider_service.connection_status }
  end

  def evolution_reconnect
    authorize @inbox, :update?
    render_evolution_action { @inbox.channel.provider_service.restart_instance }
  end

  def evolution_disconnect
    authorize @inbox, :update?
    render_evolution_action { @inbox.channel.provider_service.logout_instance }
  end

  private

  def validate_evolution_channel
    channel = @inbox.channel
    return if channel.is_a?(Channel::Whatsapp) && channel.provider == 'evolution'

    render json: { error: 'Evolution WhatsApp actions are only available for Evolution WhatsApp channels' }, status: :unprocessable_entity
  end

  def render_evolution_action
    render json: yield, status: :ok
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION WHATSAPP] #{action_name} failed for inbox #{@inbox.id}: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
