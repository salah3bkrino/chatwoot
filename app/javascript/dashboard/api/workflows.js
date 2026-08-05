import ApiClient from './ApiClient';

class WorkflowsAPI extends ApiClient {
  constructor() {
    super('workflows', { accountScoped: true });
  }
}

export default new WorkflowsAPI();
