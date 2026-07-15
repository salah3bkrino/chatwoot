<script setup>
import { ref, onMounted, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import ButtonV4 from 'next/button/Button.vue';
import BillingCard from './BillingCard.vue';
import BillingMeter from './BillingMeter.vue';
import AtmtaPaymentModal from './AtmtaPaymentModal.vue';

const { t } = useI18n();
const { currentAccount } = useAccount();
const paymentModalRef = ref(null);
const subscriptionData = ref(null);
const isLoading = ref(false);

const fetchSubscription = async () => {
  isLoading.value = true;
  try {
    const accountId = currentAccount.value.id;
    const response = await fetch(`/api/v1/accounts/${accountId}/subscription`, {
      headers: {
        'Content-Type': 'application/json',
        api_access_token: window.chatwootConfig?.userAccessToken || '',
      },
    });
    if (response.ok) {
      subscriptionData.value = await response.json();
    }
  } catch {
    // handle silently
  } finally {
    isLoading.value = false;
  }
};

const subscription = computed(() => subscriptionData.value || {});

const statusLabel = computed(() => {
  const map = {
    active: t('ATMTA_BILLING.STATUS_ACTIVE'),
    trial: t('ATMTA_BILLING.STATUS_TRIAL'),
    suspended: t('ATMTA_BILLING.STATUS_SUSPENDED'),
    expired: t('ATMTA_BILLING.STATUS_EXPIRED'),
  };
  return map[subscription.value.status] || '';
});

const statusVariant = computed(() => {
  const map = {
    active: 'success',
    trial: 'info',
    suspended: 'alert',
    expired: 'warning',
  };
  return map[subscription.value.status] || 'default';
});

const agentsPercent = computed(() => {
  if (!subscription.value.agents_limit) return 0;
  return Math.round(
    (subscription.value.agents_used / subscription.value.agents_limit) * 100
  );
});

const inboxesPercent = computed(() => {
  if (!subscription.value.inboxes_limit) return 0;
  return Math.round(
    (subscription.value.inboxes_used / subscription.value.inboxes_limit) * 100
  );
});

const openPaymentModal = () => paymentModalRef.value?.open();

onMounted(fetchSubscription);
</script>

<template>
  <div class="space-y-4">
    <BillingCard
      :title="$t('ATMTA_BILLING.TITLE')"
      :description="$t('ATMTA_BILLING.DESCRIPTION')"
    >
      <template #action>
        <ButtonV4 sm solid blue @click="openPaymentModal">
          {{ $t('ATMTA_BILLING.UPGRADE_BTN') }}
        </ButtonV4>
      </template>

      <div
        v-if="subscription.plan"
        class="grid lg:grid-cols-4 sm:grid-cols-2 grid-cols-1 gap-3 p-4"
      >
        <div class="flex flex-col gap-1">
          <span class="text-xs text-slate-500 font-medium">
            {{ $t('ATMTA_BILLING.CURRENT_PLAN') }}
          </span>
          <span class="text-sm font-bold text-slate-800">
            {{ subscription.plan?.name || $t('ATMTA_BILLING.NOT_SET') }}
          </span>
        </div>
        <div class="flex flex-col gap-1">
          <span class="text-xs text-slate-500 font-medium">
            {{ $t('ATMTA_BILLING.STATUS') }}
          </span>
          <span
            :data-variant="statusVariant"
            class="text-xs font-bold px-2 py-1 rounded-full w-fit data-[variant=success]:bg-green-50 data-[variant=success]:text-green-700 data-[variant=info]:bg-blue-50 data-[variant=info]:text-blue-700 data-[variant=alert]:bg-red-50 data-[variant=alert]:text-red-700 data-[variant=warning]:bg-yellow-50 data-[variant=warning]:text-yellow-700"
          >
            {{ statusLabel }}
          </span>
        </div>
        <div class="flex flex-col gap-1">
          <span class="text-xs text-slate-500 font-medium">
            {{ $t('ATMTA_BILLING.EXPIRES_IN') }}
          </span>
          <span class="text-sm font-semibold text-slate-700">
            {{
              subscription.days_until_expiry !== undefined
                ? `${subscription.days_until_expiry} ${$t('ATMTA_BILLING.DAYS')}`
                : $t('ATMTA_BILLING.NOT_SET')
            }}
          </span>
        </div>
        <div
          v-if="subscription.pending_payment_requests > 0"
          class="flex flex-col gap-1"
        >
          <span
            class="text-xs font-bold px-2 py-1 rounded-full bg-yellow-50 text-yellow-700 w-fit"
          >
            {{
              $t('ATMTA_BILLING.PENDING_PAYMENTS', {
                count: subscription.pending_payment_requests,
              })
            }}
          </span>
        </div>
      </div>

      <div class="px-4 pb-4 space-y-3">
        <BillingMeter
          :title="$t('ATMTA_BILLING.AGENTS')"
          :used="subscription.agents_used || 0"
          :total="subscription.agents_limit || 3"
          :percentage="agentsPercent"
        />
        <BillingMeter
          :title="$t('ATMTA_BILLING.INBOXES')"
          :used="subscription.inboxes_used || 0"
          :total="subscription.inboxes_limit || 5"
          :percentage="inboxesPercent"
        />
      </div>
    </BillingCard>

    <AtmtaPaymentModal ref="paymentModalRef" />
  </div>
</template>
