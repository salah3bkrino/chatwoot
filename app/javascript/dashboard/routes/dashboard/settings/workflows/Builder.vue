<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';
import '@vue-flow/controls/dist/style.css';

const TRIGGER_EVENTS = [
  'message_created',
  'conversation_created',
  'conversation_opened',
  'conversation_resolved',
];

const CONDITION_ATTRIBUTES = [
  { value: 'content', label: 'Message Content' },
  { value: 'has_flow_response', label: 'WhatsApp Flow Submitted' },
  { value: 'flow_name', label: 'WhatsApp Flow Name' },
  { value: 'flow_field', label: 'WhatsApp Flow Field Key' },
  { value: 'interactive_reply_id', label: 'Interactive Button / List ID' },
  { value: 'has_ad_referral', label: 'Meta Click-to-WhatsApp Ad' },
  { value: 'status', label: 'Conversation Status' },
];

const CONDITION_OPERATORS = [
  { value: 'contains', label: 'Contains' },
  { value: 'equals', label: 'Equals' },
  { value: 'not_equals', label: 'Not Equals' },
  { value: 'present', label: 'Is Present' },
  { value: 'regex', label: 'Matches Regex' },
];

const ACTION_TYPES = [
  { value: 'send_message', label: 'Send WhatsApp Message / Interactive' },
  { value: 'trigger_webhook', label: 'Trigger n8n / HTTP Webhook' },
  { value: 'add_label', label: 'Add Label' },
  { value: 'assign_team', label: 'Assign Team' },
  { value: 'resolve_conversation', label: 'Resolve Conversation' },
];

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const {
  onConnect,
  onNodeClick,
  onEdgeClick,
  addEdges,
  addNodes,
  removeNodes,
  removeEdges,
  findNode,
  findEdge,
  toObject,
} = useVueFlow();

const isEditing = ref(false);
const workflowName = ref('');
const triggerEvent = ref('message_created');
const selectedNodeId = ref(null);
const selectedEdgeId = ref(null);

const nodes = ref([
  {
    id: '1',
    type: 'input',
    label: t(
      'WORKFLOWS.BUILDER.NODE_LABELS.TRIGGER',
      'Trigger: Message Created'
    ),
    position: { x: 250, y: 20 },
    data: { type: 'trigger' },
  },
]);
const edges = ref([]);

const selectedNode = computed(() =>
  selectedNodeId.value ? findNode(selectedNodeId.value) : null
);
const selectedEdge = computed(() =>
  selectedEdgeId.value ? findEdge(selectedEdgeId.value) : null
);

const selectedNodeType = computed(
  () => selectedNode.value?.data?.type || selectedNode.value?.type || ''
);

const ensureConditionDefaults = data => {
  if (!data.attribute) data.attribute = 'content';
  if (!data.operator) data.operator = 'contains';
  if (data.value === undefined) data.value = '';
  if (data.flow_field === undefined) data.flow_field = '';
};

const ensureActionDefaults = data => {
  if (!data.action_name) data.action_name = 'send_message';
  if (!data.action_params || typeof data.action_params !== 'object') {
    data.action_params = {};
  }
  const params = data.action_params;
  if (!data.message_mode) {
    if (params.whatsapp_interactive?.type === 'flow') {
      data.message_mode = 'flow';
    } else if (
      params.whatsapp_interactive?.type === 'location_request_message'
    ) {
      data.message_mode = 'location';
    } else if (Array.isArray(params.items) && params.items.length) {
      data.message_mode = 'buttons';
    } else {
      data.message_mode = 'text';
    }
  }
};

const formatItemsText = items =>
  Array.isArray(items)
    ? items
        .map(item =>
          item.description ? `${item.title}|${item.description}` : item.title
        )
        .join('\n')
    : '';

const parseItemsText = raw =>
  String(raw || '')
    .split('\n')
    .map(line => line.trim())
    .filter(Boolean)
    .slice(0, 10)
    .map((line, index) => {
      const [titlePart, ...descParts] = line.split('|');
      const title = (titlePart || '').trim();
      const description = descParts.join('|').trim();
      const slug =
        title
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '_')
          .replace(/^_+|_+$/g, '') || `option_${index + 1}`;
      return description
        ? { title, value: slug, description }
        : { title, value: slug };
    });

const actionButtonsText = computed({
  get: () => formatItemsText(selectedNode.value?.data?.action_params?.items),
  set: val => {
    if (!selectedNode.value) return;
    ensureActionDefaults(selectedNode.value.data);
    selectedNode.value.data.action_params.items = parseItemsText(val);
    selectedNode.value.data.action_params.content_type =
      selectedNode.value.data.action_params.items.length > 0
        ? 'input_select'
        : 'text';
  },
});

const refreshNodeLabel = node => {
  if (!node?.data) return;
  if (node.data.type === 'condition') {
    const attr =
      node.data.attribute === 'flow_field'
        ? `flow_field:${node.data.flow_field || '...'}`
        : node.data.attribute || 'condition';
    node.label =
      `If ${attr} ${node.data.operator || ''} ${node.data.value || ''}`.trim();
  } else if (node.data.type === 'action') {
    const labels = {
      send_message: 'Send Message',
      trigger_webhook: 'Trigger Webhook',
      add_label: 'Add Label',
      assign_team: 'Assign Team',
      resolve_conversation: 'Resolve Conversation',
    };
    node.label = labels[node.data.action_name] || 'Action';
  }
};

const updateConditionField = (field, value) => {
  if (!selectedNode.value) return;
  ensureConditionDefaults(selectedNode.value.data);
  selectedNode.value.data[field] = value;
  if (['has_flow_response', 'has_ad_referral'].includes(value)) {
    selectedNode.value.data.operator = 'present';
  }
  refreshNodeLabel(selectedNode.value);
};

const updateActionName = value => {
  if (!selectedNode.value) return;
  ensureActionDefaults(selectedNode.value.data);
  selectedNode.value.data.action_name = value;
  refreshNodeLabel(selectedNode.value);
};

const updateMessageMode = mode => {
  if (!selectedNode.value) return;
  ensureActionDefaults(selectedNode.value.data);
  selectedNode.value.data.message_mode = mode;
  const params = selectedNode.value.data.action_params;
  if (mode === 'text') {
    delete params.content_type;
    delete params.items;
    delete params.whatsapp_interactive;
  } else if (mode === 'buttons') {
    params.content_type = 'input_select';
    delete params.whatsapp_interactive;
    if (!Array.isArray(params.items)) params.items = [];
  } else if (mode === 'location') {
    delete params.content_type;
    delete params.items;
    params.whatsapp_interactive = {
      type: 'location_request_message',
      body: params.content || 'Please share your current location.',
    };
  } else if (mode === 'flow') {
    delete params.content_type;
    delete params.items;
    params.whatsapp_interactive = {
      type: 'flow',
      flow_id: params.whatsapp_interactive?.flow_id || '',
      flow_cta: params.whatsapp_interactive?.flow_cta || 'Open Form',
      body: params.content || 'Please fill out this quick form.',
    };
  }
};

const updateActionParam = (key, value) => {
  if (!selectedNode.value) return;
  ensureActionDefaults(selectedNode.value.data);
  const params = selectedNode.value.data.action_params;
  params[key] = value;
  if (
    key === 'content' &&
    params.whatsapp_interactive &&
    ['flow', 'location_request_message'].includes(
      params.whatsapp_interactive.type
    )
  ) {
    params.whatsapp_interactive.body = value;
  }
};

const updateFlowInteractiveParam = (key, value) => {
  if (!selectedNode.value) return;
  ensureActionDefaults(selectedNode.value.data);
  const params = selectedNode.value.data.action_params;
  params.whatsapp_interactive = {
    type: 'flow',
    body: params.content || 'Please fill out this quick form.',
    ...(params.whatsapp_interactive || {}),
    [key]: value,
  };
};

const updateEdgeBranch = branch => {
  if (!selectedEdge.value) return;
  if (!branch) {
    selectedEdge.value.sourceHandle = null;
    selectedEdge.value.label = '';
  } else {
    selectedEdge.value.sourceHandle = branch;
    selectedEdge.value.label = branch === 'true' ? 'True' : 'False';
  }
};

const deleteSelectedNode = () => {
  if (!selectedNode.value || selectedNodeType.value === 'trigger') return;
  removeNodes([selectedNode.value.id]);
  selectedNodeId.value = null;
};

const deleteSelectedEdge = () => {
  if (!selectedEdge.value) return;
  removeEdges([selectedEdge.value.id]);
  selectedEdgeId.value = null;
};

onMounted(async () => {
  if (route.params.workflowId) {
    isEditing.value = true;
    await store.dispatch('workflows/get');
    const allWorkflows = store.getters['workflows/getWorkflows'];
    const workflow = allWorkflows.find(
      w => w.id === parseInt(route.params.workflowId, 10)
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

onNodeClick(({ node }) => {
  selectedEdgeId.value = null;
  selectedNodeId.value = node.id;
  if (node.data?.type === 'condition') ensureConditionDefaults(node.data);
  if (node.data?.type === 'action') ensureActionDefaults(node.data);
});

onEdgeClick(({ edge }) => {
  selectedNodeId.value = null;
  selectedEdgeId.value = edge.id;
});

const serializeActionParams = data => {
  const params = { ...(data.action_params || {}) };
  if (
    data.attribute === 'flow_field' &&
    !data.flow_field &&
    params.whatsapp_interactive
  ) {
    return params;
  }
  return params;
};

const saveWorkflow = async () => {
  const flowObject = toObject();
  const normalizedNodes = flowObject.nodes.map(node => {
    const data = { ...(node.data || {}) };
    if (data.type === 'condition' && data.attribute === 'flow_field') {
      data.attribute = `flow_field:${(data.flow_field || '').trim()}`;
    }
    if (data.type === 'action') {
      data.action_params = serializeActionParams(data);
    }
    return {
      ...node,
      type: data.type || node.type,
      data,
    };
  });

  const data = {
    name: workflowName.value,
    trigger_event: triggerEvent.value,
    nodes: normalizedNodes,
    edges: flowObject.edges,
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
  } catch {
    useAlert(t('WORKFLOWS.SAVE.ERROR'));
  }
};

const addNode = type => {
  const labelMap = {
    condition: t('WORKFLOWS.BUILDER.NODE_LABELS.CONDITION', 'Condition'),
    action: t('WORKFLOWS.BUILDER.NODE_LABELS.ACTION', 'Send Message'),
    ai_prompt: t('WORKFLOWS.BUILDER.NODE_LABELS.AI_PROMPT', 'AI Prompt'),
  };
  const data =
    type === 'condition'
      ? {
          type: 'condition',
          attribute: 'content',
          operator: 'contains',
          value: '',
        }
      : type === 'action'
        ? {
            type: 'action',
            action_name: 'send_message',
            message_mode: 'text',
            action_params: { content: '' },
          }
        : { type };
  const id = `node_${Date.now()}`;
  addNodes([
    {
      id,
      type,
      label: labelMap[type] || type,
      position: {
        x: Math.random() * 320 + 80,
        y: Math.random() * 260 + 120,
      },
      data,
    },
  ]);
  selectedEdgeId.value = null;
  selectedNodeId.value = id;
};
</script>

<template>
  <div class="flex flex-col h-full bg-n-surface-1">
    <div
      class="flex flex-wrap items-center justify-between gap-3 p-4 bg-n-solid-2 border-b border-n-weak"
    >
      <div class="flex flex-wrap items-center gap-3">
        <Button
          variant="ghost"
          icon="arrow-left"
          @click="router.push({ name: 'workflows_list' })"
        />
        <input
          v-model="workflowName"
          class="text-lg font-bold bg-transparent border-none outline-none text-n-slate-12"
          :placeholder="$t('WORKFLOWS.BUILDER.NAME_PLACEHOLDER')"
        />
        <label class="flex items-center gap-2 text-xs text-n-slate-11">
          <span>
            {{ $t('WORKFLOWS.BUILDER.TRIGGER_EVENT_LABEL', 'Trigger Event') }}
          </span>
          <select
            v-model="triggerEvent"
            class="px-2.5 py-1.5 text-xs rounded-lg bg-n-alpha-black2 text-n-slate-12 border border-n-weak focus:outline-none focus:border-n-brand"
          >
            <option v-for="evt in TRIGGER_EVENTS" :key="evt" :value="evt">
              {{ evt }}
            </option>
          </select>
        </label>
      </div>
      <div class="flex flex-wrap gap-2">
        <Button
          variant="outline"
          :label="$t('WORKFLOWS.BUILDER.ADD_CONDITION')"
          icon="split"
          @click="addNode('condition')"
        />
        <Button
          variant="outline"
          :label="$t('WORKFLOWS.BUILDER.ADD_ACTION')"
          icon="chat"
          @click="addNode('action')"
        />
        <Button
          variant="outline"
          :label="$t('WORKFLOWS.BUILDER.ADD_AI')"
          icon="sparkle"
          @click="addNode('ai_prompt')"
        />
        <Button
          :label="$t('WORKFLOWS.BUILDER.SAVE')"
          icon="save"
          @click="saveWorkflow"
        />
      </div>
    </div>

    <div class="flex flex-1 min-h-0">
      <div class="relative flex-1 w-full h-full">
        <VueFlow
          v-model:nodes="nodes"
          v-model:edges="edges"
          :default-viewport="{ zoom: 1.2, x: 0, y: 0 }"
          :min-zoom="0.2"
          :max-zoom="4"
          fit-view-on-init
        >
          <Background pattern-color="#aaa" gap="16" />
          <Controls />
        </VueFlow>
      </div>

      <aside
        class="w-80 shrink-0 border-s border-n-weak bg-n-solid-2 p-4 overflow-y-auto flex flex-col gap-4 text-start"
      >
        <div
          v-if="!selectedNode && !selectedEdge"
          class="text-xs text-n-slate-11 leading-relaxed"
        >
          {{
            $t(
              'WORKFLOWS.BUILDER.INSPECTOR.EMPTY',
              'Click any Condition, Action, or Edge on the canvas to configure it.'
            )
          }}
        </div>

        <template v-if="selectedNode">
          <div class="flex items-center justify-between gap-2">
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{
                $t('WORKFLOWS.BUILDER.INSPECTOR.NODE_TITLE', 'Node Settings')
              }}
            </h3>
            <Button
              v-if="selectedNodeType !== 'trigger'"
              size="xs"
              variant="faded"
              color="ruby"
              :label="
                $t('WORKFLOWS.BUILDER.INSPECTOR.DELETE_NODE', 'Remove Node')
              "
              @click="deleteSelectedNode"
            />
          </div>

          <div
            v-if="selectedNodeType === 'condition'"
            class="flex flex-col gap-3"
          >
            <label class="flex flex-col gap-1 text-xs text-n-slate-11">
              <span>
                {{
                  $t('WORKFLOWS.BUILDER.INSPECTOR.CONDITION_ATTR', 'Attribute')
                }}
              </span>
              <select
                :value="
                  String(selectedNode.data.attribute || '').startsWith(
                    'flow_field:'
                  )
                    ? 'flow_field'
                    : selectedNode.data.attribute
                "
                class="w-full px-2.5 py-2 text-xs rounded-lg bg-n-alpha-black2 text-n-slate-12 border border-n-weak"
                @change="updateConditionField('attribute', $event.target.value)"
              >
                <option
                  v-for="attr in CONDITION_ATTRIBUTES"
                  :key="attr.value"
                  :value="attr.value"
                >
                  {{ attr.label }}
                </option>
              </select>
            </label>

            <label
              v-if="
                selectedNode.data.attribute === 'flow_field' ||
                String(selectedNode.data.attribute || '').startsWith(
                  'flow_field:'
                )
              "
              class="flex flex-col gap-1 text-xs text-n-slate-11"
            >
              <span>
                {{
                  $t(
                    'WORKFLOWS.BUILDER.INSPECTOR.CONDITION_FLOW_FIELD',
                    'Flow Field Key (from response_json)'
                  )
                }}
              </span>
              <input
                :value="
                  selectedNode.data.flow_field ||
                  String(selectedNode.data.attribute || '').replace(
                    /^flow_field:/,
                    ''
                  )
                "
                type="text"
                class="w-full px-2.5 py-2 text-xs rounded-lg bg-n-alpha-black2 text-n-slate-12 border border-n-weak"
                @input="updateConditionField('flow_field', $event.target.value)"
              />
            </label>

            <label class="flex flex-col gap-1 text-xs text-n-slate-11">
              <span>
                {{
                  $t(
                    'WORKFLOWS.BUILDER.INSPECTOR.CONDITION_OPERATOR',
                    'Operator'
                  )
                }}
              </span>
              <select
                :value="selectedNode.data.operator"
                class="w-full px-2.5 py-2 text-xs rounded-lg bg-n-alpha-black2 text-n-slate-12 border border-n-weak"
                @change="updateConditionField('operator', $event.target.value)"
              >
                <option
                  v-for="op in CONDITION_OPERATORS"
                  :key="op.value"
                  :value="op.value"
                >
                  {{ op.label }}
                </option>
              </select>
            </label>

            <label
              v-if="selectedNode.data.operator !== 'present'"
              class="flex flex-col gap-1 text-xs text-n-slate-11"
            >
              <span>
                {{
                  $t(
                    'WORKFLOWS.BUILDER.INSPECTOR.CONDITION_VALUE',
                    'Expected Value'
                  )
                }}
              </span>
              <input
                :value="selectedNode.data.value"
                type="text"
                class="w-full px-2.5 py-2 text-xs rounded-lg bg-n-alpha-black2 text-n-slate-12 border border-n-weak"
                @input="updateConditionField('value', $event.target.value)"
              />
            </label>
          </div>

          <div
            v-else-if="selectedNodeType === 'action'"
            class="flex flex-col gap-3"
          >
            <label class="flex flex-col gap-1 text-xs text-n-slate-11">
              <span>
                {{
                  $t('WORKFLOWS.BUILDER.INSPECTOR.ACTION_TYPE', 'Action Type')
                }}
              </span>
              <select
                :value="selectedNode.data.action_name"
                class="w-full px-2.5 py-2 text-xs rounded-lg bg-n-alpha-black2 text-n-slate-12 border border-n-weak"
                @change="updateActionName($event.target.value)"
              >
                <option
                  v-for="act in ACTION_TYPES"
                  :key="act.value"
                  :value="act.value"
                >
                  {{ act.label }}
                </option>
              </select>
            </label>

            <template v-if="selectedNode.data.action_name === 'send_message'">
              <label class="flex flex-col gap-1 text-xs text-n-slate-11">
                <span>
                  {{
                    $t(
                      'WORKFLOWS.BUILDER.INSPECTOR.ACTION_CONTENT_TYPE',
                      'Message Mode'
                    )
                  }}
                </span>
                <select
                  :value="selectedNode.data.message_mode || 'text'"
                  class="w-full px-2.5 py-2 text-xs rounded-lg bg-n-alpha-black2 text-n-slate-12 border border-n-weak"
                  @change="updateMessageMode($event.target.value)"
                >
                  <option value="text">Text</option>
                  <option value="buttons">Buttons / List Menu</option>
                  <option value="flow">WhatsApp Flow</option>
                  <option value="location">GPS Location Request</option>
                </select>
              </label>

              <label class="flex flex-col gap-1 text-xs text-n-slate-11">
                <span>
                  {{
                    $t(
                      'WORKFLOWS.BUILDER.INSPECTOR.ACTION_CONTENT',
                      'Message Text'
                    )
                  }}
                </span>
                <textarea
                  rows="3"
                  :value="selectedNode.data.action_params?.content || ''"
                  class="w-full px-2.5 py-2 text-xs rounded-lg bg-n-alpha-black2 text-n-slate-12 border border-n-weak"
                  @input="updateActionParam('content', $event.target.value)"
                />
              </label>

              <label
                v-if="selectedNode.data.message_mode === 'buttons'"
                class="flex flex-col gap-1 text-xs text-n-slate-11"
              >
                <span>
                  {{
                    $t(
                      'WORKFLOWS.BUILDER.INSPECTOR.ACTION_BUTTONS_JSON',
                      'Buttons / Items (one per line or Title|description)'
                    )
                  }}
                </span>
                <textarea
                  v-model="actionButtonsText"
                  rows="4"
                  class="w-full px-2.5 py-2 text-xs rounded-lg bg-n-alpha-black2 text-n-slate-12 border border-n-weak"
                />
              </label>

              <template v-if="selectedNode.data.message_mode === 'flow'">
                <label class="flex flex-col gap-1 text-xs text-n-slate-11">
                  <span>
                    {{
                      $t(
                        'WORKFLOWS.BUILDER.INSPECTOR.ACTION_FLOW_ID',
                        'WhatsApp Flow ID'
                      )
                    }}
                  </span>
                  <input
                    :value="
                      selectedNode.data.action_params?.whatsapp_interactive
                        ?.flow_id || ''
                    "
                    type="text"
                    class="w-full px-2.5 py-2 text-xs rounded-lg bg-n-alpha-black2 text-n-slate-12 border border-n-weak"
                    @input="
                      updateFlowInteractiveParam('flow_id', $event.target.value)
                    "
                  />
                </label>
                <label class="flex flex-col gap-1 text-xs text-n-slate-11">
                  <span>
                    {{
                      $t(
                        'WORKFLOWS.BUILDER.INSPECTOR.ACTION_FLOW_CTA',
                        'Flow Button Label'
                      )
                    }}
                  </span>
                  <input
                    :value="
                      selectedNode.data.action_params?.whatsapp_interactive
                        ?.flow_cta || ''
                    "
                    type="text"
                    class="w-full px-2.5 py-2 text-xs rounded-lg bg-n-alpha-black2 text-n-slate-12 border border-n-weak"
                    @input="
                      updateFlowInteractiveParam(
                        'flow_cta',
                        $event.target.value
                      )
                    "
                  />
                </label>
              </template>
            </template>

            <label
              v-else-if="selectedNode.data.action_name === 'trigger_webhook'"
              class="flex flex-col gap-1 text-xs text-n-slate-11"
            >
              <span>
                {{
                  $t(
                    'WORKFLOWS.BUILDER.INSPECTOR.ACTION_WEBHOOK_URL',
                    'n8n / Webhook URL'
                  )
                }}
              </span>
              <input
                :value="selectedNode.data.action_params?.url || ''"
                type="url"
                placeholder="https://n8n.automationservice.cloud/webhook/..."
                class="w-full px-2.5 py-2 text-xs rounded-lg bg-n-alpha-black2 text-n-slate-12 border border-n-weak"
                @input="updateActionParam('url', $event.target.value)"
              />
            </label>

            <label
              v-else-if="selectedNode.data.action_name === 'add_label'"
              class="flex flex-col gap-1 text-xs text-n-slate-11"
            >
              <span>
                {{
                  $t(
                    'WORKFLOWS.BUILDER.INSPECTOR.ACTION_LABEL',
                    'Conversation Label'
                  )
                }}
              </span>
              <input
                :value="selectedNode.data.action_params?.label || ''"
                type="text"
                class="w-full px-2.5 py-2 text-xs rounded-lg bg-n-alpha-black2 text-n-slate-12 border border-n-weak"
                @input="updateActionParam('label', $event.target.value)"
              />
            </label>

            <label
              v-else-if="selectedNode.data.action_name === 'assign_team'"
              class="flex flex-col gap-1 text-xs text-n-slate-11"
            >
              <span>
                {{
                  $t('WORKFLOWS.BUILDER.INSPECTOR.ACTION_TEAM_ID', 'Team ID')
                }}
              </span>
              <input
                :value="selectedNode.data.action_params?.team_id || ''"
                type="number"
                class="w-full px-2.5 py-2 text-xs rounded-lg bg-n-alpha-black2 text-n-slate-12 border border-n-weak"
                @input="updateActionParam('team_id', $event.target.value)"
              />
            </label>
          </div>
        </template>

        <template v-else-if="selectedEdge">
          <div class="flex items-center justify-between gap-2">
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{
                $t(
                  'WORKFLOWS.BUILDER.INSPECTOR.EDGE_TITLE',
                  'Connection Branch'
                )
              }}
            </h3>
            <Button
              size="xs"
              variant="faded"
              color="ruby"
              :label="
                $t(
                  'WORKFLOWS.BUILDER.INSPECTOR.DELETE_EDGE',
                  'Remove Connection'
                )
              "
              @click="deleteSelectedEdge"
            />
          </div>
          <label class="flex flex-col gap-1 text-xs text-n-slate-11">
            <span>
              {{
                $t(
                  'WORKFLOWS.BUILDER.INSPECTOR.EDGE_BRANCH_LABEL',
                  'Run branch when condition is'
                )
              }}
            </span>
            <select
              :value="selectedEdge.sourceHandle || ''"
              class="w-full px-2.5 py-2 text-xs rounded-lg bg-n-alpha-black2 text-n-slate-12 border border-n-weak"
              @change="updateEdgeBranch($event.target.value)"
            >
              <option value="">Default / Always</option>
              <option value="true">True (Condition Matches)</option>
              <option value="false">False (No Match)</option>
            </select>
          </label>
        </template>
      </aside>
    </div>
  </div>
</template>
