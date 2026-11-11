<script setup>
import { computed } from 'vue';
import BaseBubble from './Base.vue';
import { useI18n } from 'vue-i18n';
import { CONTENT_TYPES } from '../constants.js';
import { useMessageContext } from '../provider.js';
import { useInbox } from 'dashboard/composables/useInbox';

const { content, contentAttributes, contentType } = useMessageContext();
const { t } = useI18n();
const { isAWebWidgetInbox } = useInbox();

const formValues = computed(() => {
  if (contentType.value === CONTENT_TYPES.FORM) {
    const { items, submittedValues = [] } = contentAttributes.value;

    if (submittedValues.length) {
      return submittedValues.map(submittedValue => {
        const item = items.find(
          formItem => formItem.name === submittedValue.name
        );
        return {
          title: submittedValue.value,
          value: submittedValue.value,
          label: item?.label,
        };
      });
    }

    return [];
  }

  if (contentType.value === CONTENT_TYPES.INPUT_SELECT) {
    const [item] = contentAttributes.value?.submittedValues ?? [];
    if (!item) return [];

    return [
      {
        title: item.title,
        value: item.value,
        label: '',
      },
    ];
  }

  return [];
});

const selectOptions = computed(() => {
  if (contentType.value !== CONTENT_TYPES.INPUT_SELECT) return [];
  if (formValues.value.length) return [];

  const items = contentAttributes.value?.items;
  return Array.isArray(items) ? items : [];
});

const hasOptionDescriptions = computed(() =>
  selectOptions.value.some(item => Boolean(item?.description))
);
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="csat">
    <span v-dompurify-html="content" :title="content" />
    <dl v-if="formValues.length" class="mt-4">
      <template v-for="item in formValues" :key="item.title">
        <dt class="text-n-slate-11 italic mt-2">
          {{ item.label || t('CONVERSATION.RESPONSE') }}
        </dt>
        <dd>{{ item.title }}</dd>
      </template>
    </dl>
    <div
      v-else-if="selectOptions.length"
      class="mt-3 flex gap-1.5"
      :class="hasOptionDescriptions ? 'flex-col' : 'flex-wrap'"
    >
      <div
        v-for="(option, index) in selectOptions"
        :key="option.value || option.title || index"
        class="px-2.5 py-1.5 rounded-lg bg-n-alpha-black1 border border-n-container text-xs text-start"
      >
        <div class="font-medium text-n-slate-12">
          {{ option.title }}
        </div>
        <div
          v-if="option.description"
          class="text-n-slate-11 mt-0.5 break-words"
        >
          {{ option.description }}
        </div>
      </div>
    </div>
    <div v-else-if="isAWebWidgetInbox" class="my-2 font-medium">
      {{ t('CONVERSATION.NO_RESPONSE') }}
    </div>
  </BaseBubble>
</template>
