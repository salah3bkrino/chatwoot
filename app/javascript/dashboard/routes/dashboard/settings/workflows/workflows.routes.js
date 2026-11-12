import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';

const WorkflowsIndex = () => import('./Index.vue');
const WorkflowBuilder = () => import('./Builder.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/workflows'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'workflows_wrapper',
          redirect: 'list',
        },
        {
          path: 'list',
          name: 'workflows_list',
          component: WorkflowsIndex,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
    {
      path: frontendURL('accounts/:accountId/settings/workflows/new'),
      name: 'workflows_new',
      component: WorkflowBuilder,
      meta: {
        permissions: ['administrator'],
      },
    },
    {
      path: frontendURL(
        'accounts/:accountId/settings/workflows/:workflowId/edit'
      ),
      name: 'workflows_edit',
      component: WorkflowBuilder,
      meta: {
        permissions: ['administrator'],
      },
    },
  ],
};
