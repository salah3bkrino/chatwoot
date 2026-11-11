<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['send', 'close', 'update:show']);

const INTERACTIVE_TYPES = {
  BUTTONS: 'buttons',
  LIST: 'list',
  LOCATION_REQUEST: 'location_request_message',
  CTA_URL: 'cta_url',
  FLOW: 'flow',
};

const MAX_BUTTONS = 3;
const MAX_LIST_ITEMS = 10;
const BUTTON_TITLE_RECOMMENDED_MAX = 20;
const BODY_MAX_LENGTH = 1024;

const { t } = useI18n();

let keyCounter = 0;
const nextKey = () => {
  keyCounter += 1;
  return keyCounter;
};

const activeType = ref(INTERACTIVE_TYPES.BUTTONS);
const headerText = ref('');
const bodyText = ref('');
const footerText = ref('');
const buttons = ref([{ key: nextKey(), title: '' }]);
const listItems = ref([{ key: nextKey(), title: '', description: '' }]);
const displayText = ref('');
const ctaUrl = ref('');
const flowId = ref('');
const flowCta = ref('');
const flowScreen = ref('');
const flowDataJson = ref('');

const localShow = computed({
  get: () => props.show,
  set: value => emit('update:show', value),
});

const defaultLocationBody = computed(() =>
  t(
    'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.LOCATION_DEFAULT_BODY',
    'Please share your current location so we can assist you better.'
  )
);

const flowDataPlaceholder = computed(() =>
  t(
    'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.FLOW_DATA_PLACEHOLDER',
    '{"customer_tier": "vip"}'
  )
);

const modeTabs = computed(() => [
  {
    id: INTERACTIVE_TYPES.BUTTONS,
    icon: 'i-ph-chat-centered-text',
    label: t('CONVERSATION.WHATSAPP_INTERACTIVE.TABS.BUTTONS', 'Buttons'),
  },
  {
    id: INTERACTIVE_TYPES.LIST,
    icon: 'i-ph-list-bullets',
    label: t('CONVERSATION.WHATSAPP_INTERACTIVE.TABS.LIST', 'Menu List'),
  },
  {
    id: INTERACTIVE_TYPES.LOCATION_REQUEST,
    icon: 'i-ph-map-pin',
    label: t(
      'CONVERSATION.WHATSAPP_INTERACTIVE.TABS.LOCATION_REQUEST',
      'Location'
    ),
  },
  {
    id: INTERACTIVE_TYPES.CTA_URL,
    icon: 'i-ph-link',
    label: t('CONVERSATION.WHATSAPP_INTERACTIVE.TABS.CTA_URL', 'Action Link'),
  },
  {
    id: INTERACTIVE_TYPES.FLOW,
    icon: 'i-ph-flow-arrow',
    label: t('CONVERSATION.WHATSAPP_INTERACTIVE.TABS.FLOW', 'Flow'),
  },
]);

const supportsHeaderAndFooter = computed(() =>
  [INTERACTIVE_TYPES.CTA_URL, INTERACTIVE_TYPES.FLOW].includes(activeType.value)
);

const isValidHttpUrl = value => {
  try {
    const parsed = new URL(value.trim());
    return ['http:', 'https:'].includes(parsed.protocol);
  } catch {
    return false;
  }
};

const showUrlError = computed(
  () =>
    activeType.value === INTERACTIVE_TYPES.CTA_URL &&
    ctaUrl.value.trim().length > 0 &&
    !isValidHttpUrl(ctaUrl.value)
);

const flowDataState = computed(() => {
  const raw = flowDataJson.value.trim();
  if (!raw) {
    return { valid: true, value: null };
  }
  try {
    const parsed = JSON.parse(raw);
    const isPlainObject =
      typeof parsed === 'object' && parsed !== null && !Array.isArray(parsed);
    return isPlainObject
      ? { valid: true, value: parsed }
      : { valid: false, value: null };
  } catch {
    return { valid: false, value: null };
  }
});

const showFlowDataError = computed(
  () =>
    activeType.value === INTERACTIVE_TYPES.FLOW &&
    flowDataJson.value.trim().length > 0 &&
    !flowDataState.value.valid
);

const trimmedBody = computed(() => bodyText.value.trim());

const isButtonsValid = computed(
  () =>
    buttons.value.length >= 1 &&
    buttons.value.length <= MAX_BUTTONS &&
    buttons.value.every(btn => btn.title.trim().length > 0)
);

const isListValid = computed(
  () =>
    listItems.value.length >= 1 &&
    listItems.value.length <= MAX_LIST_ITEMS &&
    listItems.value.every(item => item.title.trim().length > 0)
);

const isFormValid = computed(() => {
  if (!trimmedBody.value) return false;

  switch (activeType.value) {
    case INTERACTIVE_TYPES.BUTTONS:
      return isButtonsValid.value;
    case INTERACTIVE_TYPES.LIST:
      return isListValid.value;
    case INTERACTIVE_TYPES.LOCATION_REQUEST:
      return true;
    case INTERACTIVE_TYPES.CTA_URL:
      return (
        displayText.value.trim().length > 0 &&
        ctaUrl.value.trim().length > 0 &&
        isValidHttpUrl(ctaUrl.value)
      );
    case INTERACTIVE_TYPES.FLOW:
      return (
        flowId.value.trim().length > 0 &&
        flowCta.value.trim().length > 0 &&
        flowDataState.value.valid
      );
    default:
      return false;
  }
});

const buildSlug = (title, index, usedSlugs) => {
  const base = title
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 48);
  let candidate = base || `option_${index + 1}`;
  if (usedSlugs.has(candidate)) {
    candidate = `${candidate}_${index + 1}`;
  }
  usedSlugs.add(candidate);
  return candidate;
};

const selectMode = modeId => {
  const previousType = activeType.value;
  activeType.value = modeId;

  if (modeId === INTERACTIVE_TYPES.LOCATION_REQUEST && !bodyText.value.trim()) {
    bodyText.value = defaultLocationBody.value;
  } else if (
    previousType === INTERACTIVE_TYPES.LOCATION_REQUEST &&
    modeId !== INTERACTIVE_TYPES.LOCATION_REQUEST &&
    bodyText.value.trim() === defaultLocationBody.value.trim()
  ) {
    bodyText.value = '';
  }
};

const addButton = () => {
  if (buttons.value.length >= MAX_BUTTONS) return;
  buttons.value.push({ key: nextKey(), title: '' });
};

const removeButton = index => {
  if (buttons.value.length <= 1) return;
  buttons.value.splice(index, 1);
};

const addListItem = () => {
  if (listItems.value.length >= MAX_LIST_ITEMS) return;
  listItems.value.push({ key: nextKey(), title: '', description: '' });
};

const removeListItem = index => {
  if (listItems.value.length <= 1) return;
  listItems.value.splice(index, 1);
};

const resetForm = () => {
  activeType.value = INTERACTIVE_TYPES.BUTTONS;
  headerText.value = '';
  bodyText.value = '';
  footerText.value = '';
  buttons.value = [{ key: nextKey(), title: '' }];
  listItems.value = [{ key: nextKey(), title: '', description: '' }];
  displayText.value = '';
  ctaUrl.value = '';
  flowId.value = '';
  flowCta.value = '';
  flowScreen.value = '';
  flowDataJson.value = '';
};

const handleClose = () => {
  resetForm();
  emit('update:show', false);
  emit('close');
};

const buildSubmitPayload = () => {
  const usedSlugs = new Set();

  if (activeType.value === INTERACTIVE_TYPES.BUTTONS) {
    return {
      message: trimmedBody.value,
      contentType: 'input_select',
      contentAttributes: {
        items: buttons.value.map((btn, index) => ({
          title: btn.title.trim(),
          value: buildSlug(btn.title, index, usedSlugs),
        })),
      },
    };
  }

  if (activeType.value === INTERACTIVE_TYPES.LIST) {
    return {
      message: trimmedBody.value,
      contentType: 'input_select',
      contentAttributes: {
        items: listItems.value.map((item, index) => {
          const entry = {
            title: item.title.trim(),
            value: buildSlug(item.title, index, usedSlugs),
          };
          const description = item.description.trim();
          if (description) {
            entry.description = description;
          }
          return entry;
        }),
      },
    };
  }

  if (activeType.value === INTERACTIVE_TYPES.LOCATION_REQUEST) {
    return {
      message: trimmedBody.value,
      contentAttributes: {
        whatsapp_interactive: {
          type: 'location_request_message',
          body: trimmedBody.value,
        },
      },
    };
  }

  if (activeType.value === INTERACTIVE_TYPES.CTA_URL) {
    const interactive = {
      type: 'cta_url',
      body: trimmedBody.value,
      display_text: displayText.value.trim(),
      url: ctaUrl.value.trim(),
    };
    if (headerText.value.trim()) {
      interactive.header = headerText.value.trim();
    }
    if (footerText.value.trim()) {
      interactive.footer = footerText.value.trim();
    }
    return {
      message: trimmedBody.value,
      contentAttributes: {
        whatsapp_interactive: interactive,
      },
    };
  }

  const interactive = {
    type: 'flow',
    body: trimmedBody.value,
    flow_id: flowId.value.trim(),
    flow_cta: flowCta.value.trim(),
  };
  if (headerText.value.trim()) {
    interactive.header = headerText.value.trim();
  }
  if (footerText.value.trim()) {
    interactive.footer = footerText.value.trim();
  }
  if (flowScreen.value.trim()) {
    interactive.screen = flowScreen.value.trim();
  }
  if (flowDataState.value.value) {
    interactive.data = flowDataState.value.value;
  }

  return {
    message: trimmedBody.value,
    contentAttributes: {
      whatsapp_interactive: interactive,
    },
  };
};

const handleSubmit = () => {
  if (!isFormValid.value) return;
  const payload = buildSubmitPayload();
  emit('send', payload);
  resetForm();
  emit('update:show', false);
  emit('close');
};

watch(
  () => props.show,
  newValue => {
    if (!newValue) {
      resetForm();
    }
  }
);
</script>

<template>
  <woot-modal v-model:show="localShow" @close="handleClose">
    <div class="flex flex-col h-auto overflow-auto text-start">
      <woot-modal-header
        :header-title="
          t(
            'CONVERSATION.WHATSAPP_INTERACTIVE.MODAL.TITLE',
            'Send WhatsApp Interactive Message'
          )
        "
        :header-content="
          t(
            'CONVERSATION.WHATSAPP_INTERACTIVE.MODAL.SUBTITLE',
            'Choose an interactive format to engage the customer inside WhatsApp'
          )
        "
      />
      <form class="flex flex-col gap-4 w-full" @submit.prevent="handleSubmit">
        <div
          class="flex flex-wrap gap-1.5 p-1 rounded-xl bg-n-alpha-1 border border-n-weak"
        >
          <button
            v-for="tab in modeTabs"
            :key="tab.id"
            type="button"
            class="flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-medium rounded-lg transition-colors"
            :class="
              activeType === tab.id
                ? 'bg-n-solid-active text-n-blue-11 shadow-sm outline outline-1 outline-n-container'
                : 'text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2'
            "
            @click="selectMode(tab.id)"
          >
            <Icon :icon="tab.icon" class="size-3.5 shrink-0" />
            <span>{{ tab.label }}</span>
          </button>
        </div>

        <div
          v-if="activeType === INTERACTIVE_TYPES.LOCATION_REQUEST"
          class="flex items-start gap-2.5 p-3 rounded-lg bg-n-alpha-1 border border-n-weak text-xs text-n-slate-11"
        >
          <Icon
            icon="i-ph-map-pin"
            class="size-4 shrink-0 text-n-teal-11 mt-0.5"
          />
          <span>
            {{
              t(
                'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.LOCATION_HINT',
                'WhatsApp will display a native Send Location button so the customer can share their GPS pin.'
              )
            }}
          </span>
        </div>

        <Input
          v-if="supportsHeaderAndFooter"
          v-model="headerText"
          :label="
            t(
              'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.HEADER',
              'Header (optional)'
            )
          "
          :placeholder="
            t(
              'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.HEADER_PLACEHOLDER',
              'Short header text'
            )
          "
        />

        <TextArea
          id="whatsapp-interactive-body"
          v-model="bodyText"
          auto-height
          min-height="5rem"
          max-height="10rem"
          show-character-count
          :max-length="BODY_MAX_LENGTH"
          :label="
            t('CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.BODY', 'Message Body')
          "
          :placeholder="
            t(
              'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.BODY_PLACEHOLDER',
              'Write the main message shown to the customer...'
            )
          "
        />

        <div
          v-if="activeType === INTERACTIVE_TYPES.BUTTONS"
          class="flex flex-col gap-2.5"
        >
          <div class="flex items-center justify-between gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{
                t(
                  'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.BUTTONS_LABEL',
                  'Quick Reply Buttons (1–3)'
                )
              }}
            </span>
            <NextButton
              v-if="buttons.length < MAX_BUTTONS"
              type="button"
              size="xs"
              variant="faded"
              color="blue"
              icon="i-ph-plus"
              :label="
                t(
                  'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.ADD_BUTTON',
                  'Add button'
                )
              "
              @click="addButton"
            />
          </div>

          <div
            v-for="(button, index) in buttons"
            :key="button.key"
            class="flex flex-col gap-1"
          >
            <div class="flex items-center gap-2">
              <div class="flex-1 min-w-0">
                <Input
                  v-model="button.title"
                  size="sm"
                  :placeholder="
                    t(
                      'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.BUTTON_TITLE_PLACEHOLDER',
                      'Button label (max 20 chars)'
                    )
                  "
                />
              </div>
              <span
                class="text-xs tabular-nums shrink-0"
                :class="
                  button.title.trim().length > BUTTON_TITLE_RECOMMENDED_MAX
                    ? 'text-n-amber-11 font-medium'
                    : 'text-n-slate-10'
                "
              >
                {{
                  t(
                    'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.CHAR_COUNT',
                    {
                      count: button.title.trim().length,
                      max: BUTTON_TITLE_RECOMMENDED_MAX,
                    },
                    '{count}/{max}'
                  )
                }}
              </span>
              <NextButton
                type="button"
                size="xs"
                variant="ghost"
                color="slate"
                icon="i-ph-trash"
                :disabled="buttons.length <= 1"
                :aria-label="
                  t(
                    'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.REMOVE_OPTION',
                    'Remove option'
                  )
                "
                @click="removeButton(index)"
              />
            </div>
            <p
              v-if="button.title.trim().length > BUTTON_TITLE_RECOMMENDED_MAX"
              class="mb-0 text-xs text-n-amber-11"
            >
              {{
                t(
                  'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.BUTTON_LIMIT_HINT',
                  'Recommended: 20 chars or fewer for WhatsApp'
                )
              }}
            </p>
          </div>
        </div>

        <div
          v-if="activeType === INTERACTIVE_TYPES.LIST"
          class="flex flex-col gap-2.5"
        >
          <div class="flex items-center justify-between gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{
                t(
                  'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.LIST_ITEMS_LABEL',
                  'Menu Options (1–10)'
                )
              }}
            </span>
            <NextButton
              v-if="listItems.length < MAX_LIST_ITEMS"
              type="button"
              size="xs"
              variant="faded"
              color="blue"
              icon="i-ph-plus"
              :label="
                t(
                  'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.ADD_ITEM',
                  'Add option'
                )
              "
              @click="addListItem"
            />
          </div>

          <div class="flex flex-col gap-2 max-h-60 overflow-y-auto pe-1">
            <div
              v-for="(item, index) in listItems"
              :key="item.key"
              class="flex items-start gap-2 p-2.5 rounded-lg bg-n-alpha-1 border border-n-weak"
            >
              <div class="flex-1 min-w-0 flex flex-col gap-2">
                <Input
                  v-model="item.title"
                  size="sm"
                  :placeholder="
                    t(
                      'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.ITEM_TITLE_PLACEHOLDER',
                      'Option title'
                    )
                  "
                />
                <Input
                  v-model="item.description"
                  size="sm"
                  :placeholder="
                    t(
                      'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.ITEM_DESCRIPTION_PLACEHOLDER',
                      'Optional description'
                    )
                  "
                />
              </div>
              <NextButton
                type="button"
                size="xs"
                variant="ghost"
                color="slate"
                icon="i-ph-trash"
                :disabled="listItems.length <= 1"
                :aria-label="
                  t(
                    'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.REMOVE_OPTION',
                    'Remove option'
                  )
                "
                @click="removeListItem(index)"
              />
            </div>
          </div>
        </div>

        <div
          v-if="activeType === INTERACTIVE_TYPES.CTA_URL"
          class="flex flex-col gap-3"
        >
          <Input
            v-model="displayText"
            :label="
              t(
                'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.CTA_LABEL',
                'Button Label'
              )
            "
            :placeholder="
              t(
                'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.CTA_LABEL_PLACEHOLDER',
                'e.g. Track Order'
              )
            "
          />
          <Input
            v-model="ctaUrl"
            type="url"
            :message-type="showUrlError ? 'error' : 'info'"
            :message="
              showUrlError
                ? t(
                    'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.CTA_URL_ERROR',
                    'Please enter a valid http:// or https:// URL'
                  )
                : ''
            "
            :label="
              t(
                'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.CTA_URL',
                'Destination URL'
              )
            "
            :placeholder="
              t(
                'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.CTA_URL_PLACEHOLDER',
                'https://example.com/...'
              )
            "
          />
        </div>

        <div
          v-if="activeType === INTERACTIVE_TYPES.FLOW"
          class="flex flex-col gap-3"
        >
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <Input
              v-model="flowId"
              :label="
                t(
                  'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.FLOW_ID',
                  'Meta Flow ID'
                )
              "
              :placeholder="
                t(
                  'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.FLOW_ID_PLACEHOLDER',
                  'e.g. 123456789012345'
                )
              "
            />
            <Input
              v-model="flowCta"
              :label="
                t(
                  'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.FLOW_CTA',
                  'Button CTA Label'
                )
              "
              :placeholder="
                t(
                  'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.FLOW_CTA_PLACEHOLDER',
                  'e.g. Book Now'
                )
              "
            />
          </div>
          <Input
            v-model="flowScreen"
            :label="
              t(
                'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.FLOW_SCREEN',
                'Initial Screen ID (optional)'
              )
            "
            :placeholder="
              t(
                'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.FLOW_SCREEN_PLACEHOLDER',
                'e.g. WELCOME_SCREEN'
              )
            "
          />
          <div class="flex flex-col gap-1">
            <label
              for="whatsapp-interactive-flow-data"
              class="mb-0.5 text-heading-3 text-n-slate-12"
            >
              {{
                t(
                  'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.FLOW_DATA',
                  'Initial JSON Data (optional)'
                )
              }}
            </label>
            <textarea
              id="whatsapp-interactive-flow-data"
              v-model="flowDataJson"
              rows="3"
              class="w-full p-3 text-xs font-mono rounded-lg bg-n-alpha-black2 text-n-slate-12 placeholder:text-n-slate-10 outline outline-1 outline-offset-[-1px] border-0 focus:outline-n-brand"
              :class="
                showFlowDataError
                  ? 'outline-n-ruby-8 hover:outline-n-ruby-9'
                  : 'outline-n-weak hover:outline-n-slate-6'
              "
              :placeholder="flowDataPlaceholder"
            />
            <p v-if="showFlowDataError" class="mb-0 text-xs text-n-ruby-9">
              {{
                t(
                  'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.FLOW_DATA_ERROR',
                  'Enter a valid JSON object'
                )
              }}
            </p>
          </div>
        </div>

        <Input
          v-if="supportsHeaderAndFooter"
          v-model="footerText"
          :label="
            t(
              'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.FOOTER',
              'Footer (optional)'
            )
          "
          :placeholder="
            t(
              'CONVERSATION.WHATSAPP_INTERACTIVE.FIELDS.FOOTER_PLACEHOLDER',
              'Small helper note at the bottom'
            )
          "
        />

        <div class="flex items-center justify-end gap-2 pt-2">
          <NextButton
            type="button"
            variant="faded"
            color="slate"
            :label="
              t('CONVERSATION.WHATSAPP_INTERACTIVE.MODAL.CANCEL', 'Cancel')
            "
            @click="handleClose"
          />
          <NextButton
            type="submit"
            :disabled="!isFormValid"
            :label="
              t(
                'CONVERSATION.WHATSAPP_INTERACTIVE.MODAL.SEND',
                'Send Interactive Message'
              )
            "
          />
        </div>
      </form>
    </div>
  </woot-modal>
</template>
