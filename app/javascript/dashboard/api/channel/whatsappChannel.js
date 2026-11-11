/* global axios */
import ApiClient from '../ApiClient';

class WhatsappChannel extends ApiClient {
  constructor() {
    super('whatsapp', { accountScoped: true });
  }

  createEmbeddedSignup(params) {
    return axios.post(`${this.baseUrl()}/whatsapp/authorization`, params);
  }

  requestEmbeddedSignupAccess(useCase) {
    return axios.post(`${this.baseUrl()}/whatsapp/access_request`, {
      use_case: useCase,
    });
  }

  reauthorizeWhatsApp({ inboxId, ...params }) {
    return axios.post(`${this.baseUrl()}/whatsapp/authorization`, {
      ...params,
      inbox_id: inboxId,
    });
  }

  previewManualSetup(params) {
    return axios.post(`${this.baseUrl()}/whatsapp/manual/preview`, params);
  }

  connectManualSetup(params) {
    return axios.post(`${this.baseUrl()}/whatsapp/manual/connect`, params);
  }

  getManualWebhookStatus(inboxId) {
    return axios.get(
      `${this.baseUrl()}/whatsapp/manual/${inboxId}/webhook_status`
    );
  }

  setupManualWebhook(inboxId) {
    return axios.post(
      `${this.baseUrl()}/whatsapp/manual/${inboxId}/setup_webhook`
    );
  }

  getEvolutionQR(inboxId) {
    return axios.get(`${this.baseUrl()}/inboxes/${inboxId}/evolution_qr`);
  }

  getEvolutionStatus(inboxId) {
    return axios.get(`${this.baseUrl()}/inboxes/${inboxId}/evolution_status`);
  }

  reconnectEvolution(inboxId) {
    return axios.post(
      `${this.baseUrl()}/inboxes/${inboxId}/evolution_reconnect`
    );
  }

  disconnectEvolution(inboxId) {
    return axios.post(
      `${this.baseUrl()}/inboxes/${inboxId}/evolution_disconnect`
    );
  }
}

export default new WhatsappChannel();
