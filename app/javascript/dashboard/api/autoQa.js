import ApiClient from './ApiClient';

class AutoQaAPI extends ApiClient {
  constructor() {
    super('reports/auto_qa', { apiVersion: 'v2' });
  }
}

export default new AutoQaAPI();
