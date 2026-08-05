/* global axios */

import ApiClient from './ApiClient';

class AtmtaSubscriptionApi extends ApiClient {
  constructor() {
    super('subscription', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }
}

export default new AtmtaSubscriptionApi();
