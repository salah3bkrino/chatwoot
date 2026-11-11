<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import BaseBubble from './Base.vue';
import Icon from 'next/icon/Icon.vue';
import { useMessageContext } from '../provider.js';

const { content, contentAttributes } = useMessageContext();
const { t } = useI18n();

const safeUrl = value => {
  if (!value) return '';

  try {
    const parsed = new URL(value);
    return ['http:', 'https:'].includes(parsed.protocol)
      ? parsed.toString()
      : '';
  } catch {
    return '';
  }
};

const interactive = computed(
  () =>
    contentAttributes.value?.whatsappInteractive ||
    contentAttributes.value?.whatsapp_interactive ||
    {}
);

const interactiveType = computed(() => interactive.value?.type || '');

const badgeConfig = computed(() => {
  switch (interactiveType.value) {
    case 'flow':
      return {
        icon: 'i-ph-flow-arrow',
        iconClass: 'text-n-iris-11',
        label: t(
          'CONVERSATION.WHATSAPP_INTERACTIVE.TYPES.FLOW',
          'WhatsApp Flow'
        ),
      };
    case 'location_request_message':
      return {
        icon: 'i-ph-map-pin',
        iconClass: 'text-n-teal-11',
        label: t(
          'CONVERSATION.WHATSAPP_INTERACTIVE.TYPES.LOCATION_REQUEST',
          'GPS Location Request'
        ),
      };
    case 'cta_url':
      return {
        icon: 'i-ph-link',
        iconClass: 'text-n-blue-11',
        label: t(
          'CONVERSATION.WHATSAPP_INTERACTIVE.TYPES.CTA_URL',
          'Action Link'
        ),
      };
    case 'product':
    case 'product_list':
      return {
        icon: 'i-ph-shopping-bag',
        iconClass: 'text-n-amber-11',
        label: t(
          'CONVERSATION.WHATSAPP_INTERACTIVE.TYPES.PRODUCT',
          'Catalog Product'
        ),
      };
    default:
      return {
        icon: 'i-ph-lightning',
        iconClass: 'text-n-slate-11',
        label:
          interactiveType.value ||
          t(
            'CONVERSATION.WHATSAPP_INTERACTIVE.TYPES.DEFAULT',
            'Interactive Message'
          ),
      };
  }
});

const headerText = computed(() => {
  const header = interactive.value?.header;
  if (!header) return '';
  return typeof header === 'object' ? header.text || '' : String(header);
});

const bodyText = computed(() => {
  const body = interactive.value?.body;
  const extractedBody = typeof body === 'object' ? body?.text : body;
  return extractedBody || content.value || '';
});

const footerText = computed(() => {
  const footer = interactive.value?.footer;
  if (!footer) return '';
  return typeof footer === 'object' ? footer.text || '' : String(footer);
});

const displayText = computed(
  () =>
    interactive.value?.displayText ??
    interactive.value?.display_text ??
    interactive.value?.action?.parameters?.displayText ??
    interactive.value?.action?.parameters?.display_text ??
    ''
);

const ctaUrl = computed(() =>
  safeUrl(
    interactive.value?.url ?? interactive.value?.action?.parameters?.url ?? ''
  )
);

const flowId = computed(
  () =>
    interactive.value?.flowId ??
    interactive.value?.flow_id ??
    interactive.value?.action?.parameters?.flowId ??
    interactive.value?.action?.parameters?.flow_id ??
    ''
);

const flowCta = computed(
  () =>
    interactive.value?.flowCta ??
    interactive.value?.flow_cta ??
    interactive.value?.action?.parameters?.flowCta ??
    interactive.value?.action?.parameters?.flow_cta ??
    ''
);

const flowScreen = computed(
  () =>
    interactive.value?.screen ??
    interactive.value?.action?.parameters?.flowActionPayload?.screen ??
    interactive.value?.action?.parameters?.flow_action_payload?.screen ??
    ''
);

const productRetailerId = computed(
  () =>
    interactive.value?.productRetailerId ??
    interactive.value?.product_retailer_id ??
    interactive.value?.action?.productRetailerId ??
    interactive.value?.action?.product_retailer_id ??
    ''
);

const catalogId = computed(
  () =>
    interactive.value?.catalogId ??
    interactive.value?.catalog_id ??
    interactive.value?.action?.catalogId ??
    interactive.value?.action?.catalog_id ??
    ''
);

const productSections = computed(() => {
  const sections =
    interactive.value?.sections ?? interactive.value?.action?.sections;
  return Array.isArray(sections) ? sections : [];
});

const getSectionItems = section => {
  const items =
    section?.productItems ?? section?.product_items ?? section?.items;
  return Array.isArray(items) ? items : [];
};
</script>

<template>
  <BaseBubble
    class="px-4 py-3 min-w-64 max-w-lg text-start"
    data-bubble-name="whatsapp-interactive"
  >
    <div class="flex flex-col gap-2.5">
      <div
        class="inline-flex items-center gap-1.5 self-start px-2 py-0.5 rounded-md bg-n-alpha-black1 border border-n-container text-xs font-medium text-n-slate-12"
      >
        <Icon
          :icon="badgeConfig.icon"
          class="size-3.5 shrink-0"
          :class="badgeConfig.iconClass"
        />
        <span>{{ badgeConfig.label }}</span>
      </div>

      <div
        v-if="headerText"
        class="text-sm font-semibold text-n-slate-12 whitespace-pre-wrap break-words"
      >
        {{ headerText }}
      </div>

      <div
        v-if="bodyText"
        class="text-sm text-n-slate-12 whitespace-pre-wrap break-words"
      >
        {{ bodyText }}
      </div>

      <div
        v-if="footerText"
        class="text-xs text-n-slate-11 whitespace-pre-wrap break-words"
      >
        {{ footerText }}
      </div>

      <div v-if="interactiveType === 'cta_url'" class="pt-1">
        <a
          v-if="ctaUrl"
          :href="ctaUrl"
          target="_blank"
          rel="noreferrer noopener nofollow"
          class="flex items-center justify-between gap-2 px-3 py-2 rounded-lg bg-n-alpha-black1 border border-n-container hover:bg-n-alpha-2 transition-colors text-n-slate-12 no-underline"
        >
          <div class="flex flex-col min-w-0">
            <span class="text-xs font-semibold truncate">
              {{
                displayText ||
                t(
                  'CONVERSATION.WHATSAPP_INTERACTIVE.CHIPS.OPEN_LINK',
                  'Open Link'
                )
              }}
            </span>
            <span class="text-xs text-n-slate-11 truncate">
              {{ ctaUrl }}
            </span>
          </div>
          <Icon
            icon="i-ph-arrow-square-out"
            class="size-4 shrink-0 text-n-blue-11"
          />
        </a>
        <div
          v-else-if="displayText"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-n-alpha-black1 border border-n-container text-xs font-medium text-n-slate-12"
        >
          <Icon icon="i-ph-link" class="size-3.5 shrink-0 text-n-blue-11" />
          <span>{{ displayText }}</span>
        </div>
      </div>

      <div
        v-else-if="interactiveType === 'flow'"
        class="flex flex-col gap-1.5 px-3 py-2 rounded-lg bg-n-alpha-black1 border border-n-container"
      >
        <div
          class="flex items-center gap-1.5 text-xs font-semibold text-n-slate-12"
        >
          <Icon
            icon="i-ph-cursor-click"
            class="size-3.5 shrink-0 text-n-iris-11"
          />
          <span>
            {{
              flowCta ||
              t(
                'CONVERSATION.WHATSAPP_INTERACTIVE.CHIPS.OPEN_FLOW',
                'Open Flow'
              )
            }}
          </span>
        </div>
        <div
          v-if="flowId || flowScreen"
          class="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-n-slate-11"
        >
          <span v-if="flowId">
            {{
              t(
                'CONVERSATION.WHATSAPP_INTERACTIVE.CHIPS.FLOW_ID',
                { id: flowId },
                'Flow ID: {id}'
              )
            }}
          </span>
          <span v-if="flowScreen">
            {{
              t(
                'CONVERSATION.WHATSAPP_INTERACTIVE.CHIPS.SCREEN',
                { screen: flowScreen },
                'Screen: {screen}'
              )
            }}
          </span>
        </div>
      </div>

      <div
        v-else-if="interactiveType === 'location_request_message'"
        class="inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-lg bg-n-alpha-black1 border border-n-container text-xs font-medium text-n-slate-12"
      >
        <Icon icon="i-ph-map-pin" class="size-3.5 shrink-0 text-n-teal-11" />
        <span>
          {{
            t(
              'CONVERSATION.WHATSAPP_INTERACTIVE.CHIPS.SHARE_LOCATION',
              'Send Location'
            )
          }}
        </span>
      </div>

      <div
        v-else-if="
          ['product', 'product_list'].includes(interactiveType) &&
          (productRetailerId || catalogId || productSections.length)
        "
        class="flex flex-col gap-1.5 px-3 py-2 rounded-lg bg-n-alpha-black1 border border-n-container text-xs text-n-slate-11"
      >
        <div class="flex flex-wrap items-center gap-2">
          <Icon
            icon="i-ph-shopping-bag"
            class="size-3.5 shrink-0 text-n-amber-11"
          />
          <span v-if="productRetailerId" class="font-medium text-n-slate-12">
            {{
              t(
                'CONVERSATION.WHATSAPP_INTERACTIVE.CHIPS.PRODUCT_ID',
                { id: productRetailerId },
                'Product: {id}'
              )
            }}
          </span>
          <span v-if="catalogId">
            {{
              t(
                'CONVERSATION.WHATSAPP_INTERACTIVE.CHIPS.CATALOG_ID',
                { id: catalogId },
                'Catalog: {id}'
              )
            }}
          </span>
        </div>
        <div
          v-if="productSections.length"
          class="flex flex-col gap-1 pt-1 border-t border-n-weak"
        >
          <div
            v-for="(section, index) in productSections"
            :key="section.title || index"
            class="flex items-center justify-between gap-2"
          >
            <span class="font-medium text-n-slate-12 truncate">
              {{
                section.title ||
                t(
                  'CONVERSATION.WHATSAPP_INTERACTIVE.CHIPS.SECTION',
                  { index: index + 1 },
                  'Section {index}'
                )
              }}
            </span>
            <span class="shrink-0 tabular-nums">
              {{
                t(
                  'CONVERSATION.WHATSAPP_INTERACTIVE.CHIPS.SECTION_ITEMS',
                  { count: getSectionItems(section).length },
                  '{count} items'
                )
              }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </BaseBubble>
</template>
