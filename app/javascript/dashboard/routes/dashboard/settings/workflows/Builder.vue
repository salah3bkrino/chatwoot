<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';
import '@vue-flow/controls/dist/style.css';

const store = useStore();
const getters = useStoreGetters();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const { onConnect, addEdges } = useVueFlow();

const isEditing = ref(false);
const workflowName = ref('');
const triggerEvent = ref('message_created');
const selectedNodeId = ref(null);

const nodes = ref([
  {
    id: 'trigger',
    type: 'input',
    label: t('WORKFLOWS.BUILDER.NODE_LABELS.TRIGGER'),
    position: { x: 40, y: 180 },
    data: { type: 'trigger' },
  },
]);
const edges = ref([]);

const agents = computed(() => getters['agents/getAgents'].value || []);
const teams = computed(() => getters['teams/getTeams'].value || []);
const selectedNode = computed(() =>
  nodes.value.find(node => node.id === selectedNodeId.value)
);

const triggerEvents = computed(() => [
  {
    value: 'message_created',
    label: t('WORKFLOWS.BUILDER.TRIGGERS.MESSAGE_CREATED'),
  },
  {
    value: 'conversation_created',
    label: t('WORKFLOWS.BUILDER.TRIGGERS.CONVERSATION_CREATED'),
  },
  {
    value: 'conversation_updated',
    label: t('WORKFLOWS.BUILDER.TRIGGERS.CONVERSATION_UPDATED'),
  },
  {
    value: 'conversation_opened',
    label: t('WORKFLOWS.BUILDER.TRIGGERS.CONVERSATION_OPENED'),
  },
  {
    value: 'conversation_resolved',
    label: t('WORKFLOWS.BUILDER.TRIGGERS.CONVERSATION_RESOLVED'),
  },
]);

const conditionAttributes = computed(() => [
  {
    value: 'message_content',
    label: t('WORKFLOWS.BUILDER.CONDITIONS.MESSAGE_CONTENT'),
  },
  {
    value: 'conversation_status',
    label: t('WORKFLOWS.BUILDER.CONDITIONS.CONVERSATION_STATUS'),
  },
  {
    value: 'conversation_priority',
    label: t('WORKFLOWS.BUILDER.CONDITIONS.CONVERSATION_PRIORITY'),
  },
  {
    value: 'contact_email',
    label: t('WORKFLOWS.BUILDER.CONDITIONS.CONTACT_EMAIL'),
  },
]);

const conditionOperators = computed(() => [
  { value: 'contains', label: t('WORKFLOWS.BUILDER.OPERATORS.CONTAINS') },
  { value: 'equals', label: t('WORKFLOWS.BUILDER.OPERATORS.EQUALS') },
  { value: 'not_equals', label: t('WORKFLOWS.BUILDER.OPERATORS.NOT_EQUALS') },
  { value: 'present', label: t('WORKFLOWS.BUILDER.OPERATORS.PRESENT') },
]);

const actionTypes = computed(() => [
  { value: 'send_message', label: t('WORKFLOWS.BUILDER.ACTIONS.SEND_MESSAGE') },
  { value: 'add_label', label: t('WORKFLOWS.BUILDER.ACTIONS.ADD_LABEL') },
  { value: 'assign_agent', label: t('WORKFLOWS.BUILDER.ACTIONS.ASSIGN_AGENT') },
  { value: 'assign_team', label: t('WORKFLOWS.BUILDER.ACTIONS.ASSIGN_TEAM') },
  { value: 'send_webhook', label: t('WORKFLOWS.BUILDER.ACTIONS.SEND_WEBHOOK') },
]);

const nodeLabel = data => {
  if (data.type === 'condition')
    return t('WORKFLOWS.BUILDER.NODE_LABELS.CONDITION');
  if (data.type === 'action') {
    return actionTypes.value.find(action => action.value === data.action_name)
      ?.label;
  }
  return t('WORKFLOWS.BUILDER.NODE_LABELS.TRIGGER');
};

onMounted(async () => {
  store.dispatch('agents/get');
  store.dispatch('teams/get');

  if (route.params.workflowId) {
    isEditing.value = true;
    const workflow = await store.dispatch(
      'workflows/show',
      route.params.workflowId
    );
    if (workflow) {
      workflowName.value = workflow.name;
      triggerEvent.value = workflow.trigger_event;
      nodes.value = workflow.nodes || [];
      edges.value = workflow.edges || [];
    }
  }
});

onConnect(params => addEdges(params));

const addNode = data => {
  const id = `node_${Date.now()}`;
  nodes.value.push({
    id,
    type: 'default',
    label: nodeLabel(data),
    position: {
      x: 260 + (nodes.value.length % 3) * 220,
      y: 80 + Math.floor(nodes.value.length / 3) * 160,
    },
    data,
  });
  selectedNodeId.value = id;
};

const addCondition = () => {
  addNode({
    type: 'condition',
    attribute: 'message_content',
    operator: 'contains',
    value: '',
  });
};

const addAction = actionName => {
  addNode({ type: 'action', action_name: actionName, action_params: {} });
};

const selectNode = ({ node }) => {
  selectedNodeId.value = node.id;
};

const updateSelectedNode = attributes => {
  if (!selectedNode.value) return;

  const data = { ...selectedNode.value.data, ...attributes };
  nodes.value = nodes.value.map(node =>
    node.id === selectedNode.value.id
      ? { ...node, label: nodeLabel(data), data }
      : node
  );
};

const updateAction = actionName => {
  updateSelectedNode({ action_name: actionName, action_params: {} });
};

const updateActionParam = (key, value) => {
  updateSelectedNode({
    action_params: {
      ...(selectedNode.value.data.action_params || {}),
      [key]: value,
    },
  });
};

const removeSelectedNode = () => {
  if (!selectedNode.value || selectedNode.value.data.type === 'trigger') return;

  const nodeId = selectedNode.value.id;
  nodes.value = nodes.value.filter(node => node.id !== nodeId);
  edges.value = edges.value.filter(
    edge => edge.source !== nodeId && edge.target !== nodeId
  );
  selectedNodeId.value = null;
};

const saveWorkflow = async () => {
  if (!workflowName.value.trim()) {
    useAlert(t('WORKFLOWS.SAVE.NAME_REQUIRED'));
    return;
  }

  if (nodes.value.length < 2 || !edges.value.length) {
    useAlert(t('WORKFLOWS.SAVE.GRAPH_REQUIRED'));
    return;
  }

  const data = {
    name: workflowName.value,
    trigger_event: triggerEvent.value,
    nodes: nodes.value,
    edges: edges.value,
    active: true,
  };

  try {
    if (isEditing.value) {
      await store.dispatch('workflows/update', {
        id: route.params.workflowId,
        ...data,
      });
    } else {
      await store.dispatch('workflows/create', data);
    }
    useAlert(t('WORKFLOWS.SAVE.SUCCESS'));
    router.push({ name: 'workflows_list' });
  } catch (error) {
    useAlert(t('WORKFLOWS.SAVE.ERROR'));
  }
};
</script>

<template>
  <div class="flex h-full flex-col bg-slate-50 dark:bg-slate-900">
    <div
      class="flex items-center justify-between gap-4 border-b border-slate-200 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900"
    >
      <div class="flex items-center gap-4">
        <Button
          variant="ghost"
          icon="arrow-left"
          @click="router.push({ name: 'workflows_list' })"
        />
        <input
          v-model="workflowName"
          class="border-none bg-transparent text-lg font-bold outline-none dark:text-white"
          :placeholder="$t('WORKFLOWS.BUILDER.NAME_PLACEHOLDER')"
        />
      </div>
      <div class="flex flex-wrap justify-end gap-2">
        <Button
          variant="outline"
          :label="$t('WORKFLOWS.BUILDER.ADD_CONDITION')"
          icon="split"
          @click="addCondition"
        />
        <Button
          variant="outline"
          :label="$t('WORKFLOWS.BUILDER.ADD_REPLY')"
          icon="chat"
          @click="addAction('send_message')"
        />
        <Button
          variant="outline"
          :label="$t('WORKFLOWS.BUILDER.ADD_LABEL')"
          icon="price-tag-3"
          @click="addAction('add_label')"
        />
        <Button
          variant="outline"
          :label="$t('WORKFLOWS.BUILDER.ADD_ASSIGNMENT')"
          icon="user-follow"
          @click="addAction('assign_agent')"
        />
        <Button
          variant="outline"
          :label="$t('WORKFLOWS.BUILDER.ADD_WEBHOOK')"
          icon="links"
          @click="addAction('send_webhook')"
        />
        <Button
          :label="$t('WORKFLOWS.BUILDER.SAVE')"
          icon="save"
          @click="saveWorkflow"
        />
      </div>
    </div>

    <div class="relative h-full flex-1">
      <VueFlow
        v-model:nodes="nodes"
        v-model:edges="edges"
        :default-viewport="{ zoom: 1.2, x: 0, y: 0 }"
        :min-zoom="0.2"
        :max-zoom="4"
        fit-view-on-init
        @node-click="selectNode"
      >
        <Background pattern-color="#aaa" gap="16" />
        <Controls />
      </VueFlow>

      <aside
        v-if="selectedNode"
        class="absolute right-4 top-4 z-10 w-80 rounded-lg border border-slate-200 bg-white p-4 shadow-lg dark:border-slate-700 dark:bg-slate-900"
      >
        <div class="mb-4 flex items-center justify-between">
          <h2 class="text-sm font-semibold text-slate-900 dark:text-slate-100">
            {{ $t('WORKFLOWS.BUILDER.PROPERTIES') }}
          </h2>
          <Button
            v-if="selectedNode.data.type !== 'trigger'"
            variant="ghost"
            color="red"
            icon="delete"
            @click="removeSelectedNode"
          />
        </div>

        <template v-if="selectedNode.data.type === 'trigger'">
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-200"
          >
            {{ $t('WORKFLOWS.BUILDER.TRIGGER_EVENT') }}
            <select v-model="triggerEvent" class="mt-1 w-full">
              <option
                v-for="event in triggerEvents"
                :key="event.value"
                :value="event.value"
              >
                {{ event.label }}
              </option>
            </select>
          </label>
        </template>

        <template v-else-if="selectedNode.data.type === 'condition'">
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-200"
          >
            {{ $t('WORKFLOWS.BUILDER.CONDITION_ATTRIBUTE') }}
            <select
              class="mt-1 w-full"
              :value="selectedNode.data.attribute"
              @change="updateSelectedNode({ attribute: $event.target.value })"
            >
              <option
                v-for="attribute in conditionAttributes"
                :key="attribute.value"
                :value="attribute.value"
              >
                {{ attribute.label }}
              </option>
            </select>
          </label>
          <label
            class="mt-3 block text-sm font-medium text-slate-700 dark:text-slate-200"
          >
            {{ $t('WORKFLOWS.BUILDER.CONDITION_OPERATOR') }}
            <select
              class="mt-1 w-full"
              :value="selectedNode.data.operator"
              @change="updateSelectedNode({ operator: $event.target.value })"
            >
              <option
                v-for="operator in conditionOperators"
                :key="operator.value"
                :value="operator.value"
              >
                {{ operator.label }}
              </option>
            </select>
          </label>
          <label
            v-if="selectedNode.data.operator !== 'present'"
            class="mt-3 block text-sm font-medium text-slate-700 dark:text-slate-200"
          >
            {{ $t('WORKFLOWS.BUILDER.CONDITION_VALUE') }}
            <input
              class="mt-1 w-full"
              :value="selectedNode.data.value"
              @input="updateSelectedNode({ value: $event.target.value })"
            />
          </label>
          <p class="mt-3 text-xs text-slate-500">
            {{ $t('WORKFLOWS.BUILDER.CONDITION_HINT') }}
          </p>
        </template>

        <template v-else>
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-200"
          >
            {{ $t('WORKFLOWS.BUILDER.ACTION_TYPE') }}
            <select
              class="mt-1 w-full"
              :value="selectedNode.data.action_name"
              @change="updateAction($event.target.value)"
            >
              <option
                v-for="action in actionTypes"
                :key="action.value"
                :value="action.value"
              >
                {{ action.label }}
              </option>
            </select>
          </label>
          <label
            v-if="selectedNode.data.action_name === 'send_message'"
            class="mt-3 block text-sm font-medium text-slate-700 dark:text-slate-200"
          >
            {{ $t('WORKFLOWS.BUILDER.MESSAGE_CONTENT') }}
            <textarea
              class="mt-1 w-full"
              rows="4"
              :value="selectedNode.data.action_params?.content"
              @input="updateActionParam('content', $event.target.value)"
            />
          </label>
          <label
            v-else-if="selectedNode.data.action_name === 'add_label'"
            class="mt-3 block text-sm font-medium text-slate-700 dark:text-slate-200"
          >
            {{ $t('WORKFLOWS.BUILDER.LABEL_NAME') }}
            <input
              class="mt-1 w-full"
              :value="selectedNode.data.action_params?.label"
              @input="updateActionParam('label', $event.target.value)"
            />
          </label>
          <label
            v-else-if="selectedNode.data.action_name === 'assign_agent'"
            class="mt-3 block text-sm font-medium text-slate-700 dark:text-slate-200"
          >
            {{ $t('WORKFLOWS.BUILDER.AGENT') }}
            <select
              class="mt-1 w-full"
              :value="selectedNode.data.action_params?.agent_id"
              @change="updateActionParam('agent_id', $event.target.value)"
            >
              <option value="">
                {{ $t('WORKFLOWS.BUILDER.SELECT_AGENT') }}
              </option>
              <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                {{ agent.name }}
              </option>
            </select>
          </label>
          <label
            v-else-if="selectedNode.data.action_name === 'assign_team'"
            class="mt-3 block text-sm font-medium text-slate-700 dark:text-slate-200"
          >
            {{ $t('WORKFLOWS.BUILDER.TEAM') }}
            <select
              class="mt-1 w-full"
              :value="selectedNode.data.action_params?.team_id"
              @change="updateActionParam('team_id', $event.target.value)"
            >
              <option value="">
                {{ $t('WORKFLOWS.BUILDER.SELECT_TEAM') }}
              </option>
              <option v-for="team in teams" :key="team.id" :value="team.id">
                {{ team.name }}
              </option>
            </select>
          </label>
          <label
            v-else-if="selectedNode.data.action_name === 'send_webhook'"
            class="mt-3 block text-sm font-medium text-slate-700 dark:text-slate-200"
          >
            {{ $t('WORKFLOWS.BUILDER.WEBHOOK_URL') }}
            <input
              class="mt-1 w-full"
              type="url"
              :value="selectedNode.data.action_params?.url"
              @input="updateActionParam('url', $event.target.value)"
            />
          </label>
        </template>
      </aside>
    </div>
  </div>
</template>
