<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import BaseBubble from './Base.vue';
import Icon from 'next/icon/Icon.vue';
import { useMessageContext } from '../provider.js';

const { content, contentAttributes } = useMessageContext();
const { t } = useI18n();

const order = computed(
  () =>
    contentAttributes.value?.whatsappOrder ||
    contentAttributes.value?.whatsapp_order ||
    {}
);

const catalogId = computed(
  () => order.value?.catalogId ?? order.value?.catalog_id ?? ''
);

const rawItems = computed(
  () => order.value?.productItems ?? order.value?.product_items ?? []
);

const orderNote = computed(
  () => order.value?.text || (rawItems.value.length ? '' : content.value) || ''
);

const orderCurrency = computed(() => {
  if (order.value?.currency) return order.value.currency;
  const itemWithCurrency = rawItems.value.find(item => item?.currency);
  return itemWithCurrency?.currency || '';
});

const formatPrice = (amount, currency) => {
  if (amount === null || amount === undefined || amount === '') return '';
  const numeric = Number(amount);
  if (Number.isNaN(numeric)) return String(amount);

  if (currency) {
    try {
      return new Intl.NumberFormat(undefined, {
        style: 'currency',
        currency,
      }).format(numeric);
    } catch {
      return `${numeric.toFixed(2)} ${currency}`;
    }
  }

  return numeric.toFixed(2);
};

const productItems = computed(() =>
  rawItems.value.map((item, index) => {
    const retailerId =
      item.productRetailerId ??
      item.product_retailer_id ??
      item.retailerId ??
      item.retailer_id ??
      '';
    const title =
      item.name ?? item.title ?? item.productName ?? item.product_name ?? '';
    const quantity = Number(item.quantity ?? 1) || 1;
    const rawUnitPrice =
      item.itemPrice ?? item.item_price ?? item.price ?? null;
    const numericPrice =
      rawUnitPrice !== null && rawUnitPrice !== ''
        ? Number(rawUnitPrice)
        : null;
    const hasValidPrice = numericPrice !== null && !Number.isNaN(numericPrice);
    const currency = item.currency || orderCurrency.value;
    const lineTotal = hasValidPrice ? numericPrice * quantity : null;

    return {
      key: `${retailerId || 'item'}-${index}`,
      retailerId,
      title,
      quantity,
      unitPriceFormatted: hasValidPrice
        ? formatPrice(numericPrice, currency)
        : '',
      lineTotal,
      lineTotalFormatted:
        lineTotal !== null ? formatPrice(lineTotal, currency) : '',
    };
  })
);

const itemCountLabel = computed(() => {
  const count = productItems.value.length;
  return count === 1
    ? t('CONVERSATION.WHATSAPP_ORDER.ITEM_SINGLE', '1 item')
    : t('CONVERSATION.WHATSAPP_ORDER.ITEMS_COUNT', { count }, '{count} items');
});

const totalFormatted = computed(() => {
  const explicitTotal =
    order.value?.totalAmount ??
    order.value?.total_amount ??
    order.value?.total ??
    null;

  if (explicitTotal !== null && explicitTotal !== '') {
    return formatPrice(explicitTotal, orderCurrency.value);
  }

  const pricedItems = productItems.value.filter(
    item => item.lineTotal !== null
  );
  if (!pricedItems.length) return '';

  const sum = pricedItems.reduce((acc, item) => acc + item.lineTotal, 0);
  return formatPrice(sum, orderCurrency.value);
});
</script>

<template>
  <BaseBubble
    class="px-4 py-3 min-w-64 max-w-lg text-start"
    data-bubble-name="whatsapp-order"
  >
    <div class="flex flex-col gap-3">
      <div class="flex items-center justify-between gap-2">
        <div class="flex items-center gap-2 min-w-0">
          <div
            class="flex items-center justify-center rounded-lg size-7 bg-n-alpha-black1 border border-n-container shrink-0"
          >
            <Icon icon="i-ph-shopping-bag" class="size-4 text-n-teal-11" />
          </div>
          <div class="flex flex-col min-w-0">
            <span class="text-sm font-semibold text-n-slate-12 truncate">
              {{ t('CONVERSATION.WHATSAPP_ORDER.TITLE', 'WhatsApp Order') }}
            </span>
            <span v-if="catalogId" class="text-xs text-n-slate-11 truncate">
              {{
                t(
                  'CONVERSATION.WHATSAPP_ORDER.CATALOG',
                  { catalogId },
                  'Catalog #{catalogId}'
                )
              }}
            </span>
          </div>
        </div>
        <span
          v-if="productItems.length"
          class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-alpha-black1 border border-n-container text-n-slate-11 shrink-0"
        >
          {{ itemCountLabel }}
        </span>
      </div>

      <p
        v-if="orderNote"
        class="mb-0 text-sm text-n-slate-12 whitespace-pre-wrap break-words"
      >
        {{ orderNote }}
      </p>

      <div
        v-if="productItems.length"
        class="flex flex-col divide-y divide-n-weak rounded-lg bg-n-alpha-black1 border border-n-container overflow-hidden"
      >
        <div
          v-for="item in productItems"
          :key="item.key"
          class="flex items-center justify-between gap-3 px-3 py-2 text-xs"
        >
          <div class="flex flex-col min-w-0">
            <span class="font-medium text-n-slate-12 truncate">
              {{ item.title || item.retailerId }}
            </span>
            <span
              v-if="item.title && item.retailerId"
              class="text-n-slate-11 truncate"
            >
              {{ item.retailerId }}
            </span>
            <span v-if="item.unitPriceFormatted" class="text-n-slate-11">
              {{
                t(
                  'CONVERSATION.WHATSAPP_ORDER.UNIT_PRICE',
                  { price: item.unitPriceFormatted },
                  '{price} each'
                )
              }}
            </span>
          </div>
          <div class="flex items-center gap-3 shrink-0 tabular-nums">
            <span
              class="px-1.5 py-0.5 rounded bg-n-alpha-2 text-n-slate-12 font-medium"
            >
              {{
                t(
                  'CONVERSATION.WHATSAPP_ORDER.QUANTITY',
                  { count: item.quantity },
                  '{count}x'
                )
              }}
            </span>
            <span
              v-if="item.lineTotalFormatted"
              class="font-medium text-n-slate-12 min-w-14 text-end"
            >
              {{ item.lineTotalFormatted }}
            </span>
          </div>
        </div>
      </div>

      <div
        v-if="totalFormatted"
        class="flex items-center justify-between pt-2 border-t border-n-weak text-sm"
      >
        <span class="font-medium text-n-slate-11">
          {{ t('CONVERSATION.WHATSAPP_ORDER.TOTAL', 'Total') }}
        </span>
        <span class="font-semibold text-n-slate-12 tabular-nums">
          {{ totalFormatted }}
        </span>
      </div>
    </div>
  </BaseBubble>
</template>
