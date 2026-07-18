/* global axios */

import ApiClient from './ApiClient';

class AtmtaSubscriptionApi extends ApiClient {
  constructor() {
    super('subscription', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  getPlans() {
    return axios.get(`${this.url}/plans`);
  }

  createManualPayment(payload) {
    return axios.post(`${this.url}/manual_payment`, payload);
  }
}

export default new AtmtaSubscriptionApi();
