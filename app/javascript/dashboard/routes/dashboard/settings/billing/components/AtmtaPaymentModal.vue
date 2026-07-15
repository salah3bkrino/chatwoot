<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import ButtonV4 from 'next/button/Button.vue';
import Modal from 'dashboard/components/Modal.vue';

const emit = defineEmits(['success']);
const { t } = useI18n();
const { currentAccount } = useAccount();

const isOpen = ref(false);
const selectedPlan = ref(null);
const selectedMethod = ref('vodafone_cash');
const senderPhone = ref('');
const transferRef = ref('');
const months = ref(1);
const isSubmitting = ref(false);
const step = ref(1);

const plans = ref([
  {
    id: 1,
    name: 'Starter',
    price: 49,
    maxAgents: 3,
    maxInboxes: 5,
    features: [
      t('ATMTA_BILLING.PLAN_FEATURE.WHATSAPP'),
      t('ATMTA_BILLING.PLAN_FEATURE.CAPTAIN'),
      t('ATMTA_BILLING.PLAN_FEATURE.CAMPAIGNS'),
    ],
  },
  {
    id: 2,
    name: 'Enterprise',
    price: 99,
    maxAgents: 999,
    maxInboxes: 50,
    features: [
      t('ATMTA_BILLING.PLAN_FEATURE.ALL_STARTER'),
      t('ATMTA_BILLING.PLAN_FEATURE.UNLIMITED_AGENTS'),
      t('ATMTA_BILLING.PLAN_FEATURE.PRIORITY_SUPPORT'),
      t('ATMTA_BILLING.PLAN_FEATURE.GREEN_TICK'),
    ],
  },
]);

const paymentMethods = [
  {
    value: 'vodafone_cash',
    label: t('ATMTA_BILLING.PAYMENT_METHOD.VODAFONE'),
    icon: '📱',
    number: '01XXXXXXXXX',
    external: false,
  },
  {
    value: 'instapay',
    label: t('ATMTA_BILLING.PAYMENT_METHOD.INSTAPAY'),
    icon: '💳',
    number: 'atmta@instapay',
    external: false,
  },
  {
    value: 'stripe',
    label: t('ATMTA_BILLING.PAYMENT_METHOD.STRIPE'),
    icon: '💳',
    number: '',
    external: true,
  },
];

const selectedPaymentDetails = computed(() =>
  paymentMethods.find(m => m.value === selectedMethod.value)
);

const totalEGP = computed(() => {
  if (!selectedPlan.value) return 0;
  return selectedPlan.value.price * 50 * months.value;
});

const monthOptions = [1, 3, 6, 12];

const agentLabel = plan =>
  plan.maxAgents === 999
    ? t('ATMTA_BILLING.MODAL.UNLIMITED_AGENTS')
    : t('ATMTA_BILLING.MODAL.UP_TO_AGENTS', { count: plan.maxAgents });

const inboxLabel = plan =>
  t('ATMTA_BILLING.MODAL.INBOXES_COUNT', { count: plan.maxInboxes });

const monthLabel = m =>
  m === 1 ? t('ATMTA_BILLING.MODAL.MONTH') : t('ATMTA_BILLING.MODAL.MONTHS');

const open = () => {
  isOpen.value = true;
  step.value = 1;
};

const close = () => {
  isOpen.value = false;
};

const selectPlan = plan => {
  selectedPlan.value = plan;
  step.value = 2;
};

const handleStripeCheckout = () => {
  const accountId = currentAccount.value.id;
  window.open(
    `/api/v1/accounts/${accountId}/subscription/stripe_checkout?plan_id=${selectedPlan.value.id}&months=${months.value}`,
    '_blank'
  );
  close();
};

const submitManualPayment = async () => {
  if (!senderPhone.value || !transferRef.value) return;
  isSubmitting.value = true;
  try {
    const accountId = currentAccount.value.id;
    const response = await fetch(
      `/api/v1/accounts/${accountId}/subscription/manual_payment`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          api_access_token: window.chatwootConfig?.userAccessToken || '',
        },
        body: JSON.stringify({
          plan_id: selectedPlan.value.id,
          payment_method: selectedMethod.value,
          sender_phone: senderPhone.value,
          transfer_reference: transferRef.value,
          amount: totalEGP.value,
          currency: 'EGP',
          months: months.value,
        }),
      }
    );
    if (!response.ok) throw new Error('request_failed');
    emit('success');
    close();
    useAlert(t('ATMTA_BILLING.MODAL.SUCCESS_MSG'));
  } catch {
    useAlert(t('ATMTA_BILLING.MODAL.ERROR_MSG'));
  } finally {
    isSubmitting.value = false;
  }
};

defineExpose({ open, close });
</script>

<template>
  <Modal :show="isOpen" @close="close">
    <template #header>
      <div class="flex items-center gap-2 p-6 border-b border-slate-100">
        <div>
          <h2 class="text-lg font-bold text-slate-800">
            {{ $t('ATMTA_BILLING.MODAL.TITLE') }}
          </h2>
          <p class="text-sm text-slate-500">
            {{ $t('ATMTA_BILLING.MODAL.DESCRIPTION') }}
          </p>
        </div>
      </div>
    </template>

    <div class="p-6">
      <!-- Step 1: Select plan -->
      <div v-if="step === 1" class="space-y-4">
        <h3 class="text-sm font-bold text-slate-700 mb-3">
          {{ $t('ATMTA_BILLING.MODAL.SELECT_PLAN') }}
        </h3>
        <div class="grid grid-cols-1 gap-4">
          <div
            v-for="plan in plans"
            :key="plan.id"
            class="border-2 rounded-xl p-5 cursor-pointer transition-all hover:border-blue-400 hover:bg-blue-50/30"
            :class="
              selectedPlan?.id === plan.id
                ? 'border-blue-500 bg-blue-50'
                : 'border-slate-200'
            "
            @click="selectPlan(plan)"
          >
            <div class="flex justify-between items-start">
              <div>
                <h4 class="font-bold text-slate-800 text-lg">
                  {{ plan.name }}
                </h4>
                <p class="text-xs text-slate-500">
                  {{ agentLabel(plan) }} {{ '·' }} {{ inboxLabel(plan) }}
                </p>
              </div>
              <div class="text-right">
                <div class="text-2xl font-black text-blue-600">
                  {{ $t('ATMTA_BILLING.MODAL.PRICE', { price: plan.price }) }}
                </div>
                <div class="text-xs text-slate-400">
                  {{ $t('ATMTA_BILLING.MODAL.PER_MONTH') }}
                </div>
              </div>
            </div>
            <ul class="mt-3 space-y-1">
              <li
                v-for="feature in plan.features"
                :key="feature"
                class="text-xs text-slate-600 flex items-center gap-1"
              >
                <i class="i-lucide-check text-green-500" />
                {{ feature }}
              </li>
            </ul>
          </div>
        </div>
      </div>

      <!-- Step 2: Select payment method & months -->
      <div v-else-if="step === 2" class="space-y-4">
        <div class="flex items-center gap-2 text-sm text-slate-600 mb-4">
          <button
            class="text-blue-500 flex items-center gap-1 hover:underline"
            @click="() => (step = 1)"
          >
            <i class="i-lucide-arrow-left" />
            {{ $t('ATMTA_BILLING.MODAL.BACK') }}
          </button>
        </div>

        <div class="mb-4">
          <label class="block text-sm font-medium text-slate-700 mb-2">
            {{ $t('ATMTA_BILLING.MODAL.MONTHS_LABEL') }}
          </label>
          <div class="flex gap-2 flex-wrap">
            <button
              v-for="m in monthOptions"
              :key="m"
              class="px-4 py-2 rounded-lg border text-sm font-medium transition flex items-center gap-1"
              :class="[
                months === m
                  ? 'border-blue-500 bg-blue-50 text-blue-700'
                  : 'border-slate-200 text-slate-600 hover:bg-slate-50',
              ]"
              @click="months = m"
            >
              {{ m }} {{ monthLabel(m) }}
              <span v-if="m >= 6" class="text-xs text-green-600">
                {{ $t('ATMTA_BILLING.MODAL.DISCOUNT') }}
              </span>
            </button>
          </div>
        </div>

        <h3 class="text-sm font-bold text-slate-700">
          {{ $t('ATMTA_BILLING.MODAL.SELECT_METHOD') }}
        </h3>
        <div class="space-y-3">
          <div
            v-for="method in paymentMethods"
            :key="method.value"
            class="border-2 rounded-xl p-4 cursor-pointer transition-all hover:border-blue-400"
            :class="
              selectedMethod === method.value
                ? 'border-blue-500 bg-blue-50'
                : 'border-slate-200'
            "
            @click="
              selectedMethod = method.value;
              if (!method.external) step = 3;
            "
          >
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-3">
                <span class="text-2xl">{{ method.icon }}</span>
                <div>
                  <div class="font-medium text-slate-800">
                    {{ method.label }}
                  </div>
                  <div v-if="!method.external" class="text-xs text-slate-500">
                    {{ method.number }}
                  </div>
                </div>
              </div>
              <ButtonV4
                v-if="method.external"
                sm
                solid
                blue
                @click.stop="handleStripeCheckout"
              >
                {{ $t('ATMTA_BILLING.MODAL.PAY_NOW') }}
                <i class="i-lucide-arrow-right ml-1" />
              </ButtonV4>
            </div>
          </div>
        </div>
      </div>

      <!-- Step 3: Transfer details -->
      <div v-else-if="step === 3" class="space-y-4">
        <div class="flex items-center gap-2 text-sm text-slate-600 mb-4">
          <button
            class="text-blue-500 flex items-center gap-1 hover:underline"
            @click="() => (step = 2)"
          >
            <i class="i-lucide-arrow-left" />
            {{ $t('ATMTA_BILLING.MODAL.BACK') }}
          </button>
          <span class="text-slate-400">{{ '·' }}</span>
          <span>{{ selectedPaymentDetails?.label }}</span>
        </div>

        <div class="bg-blue-50 border border-blue-200 rounded-xl p-4 text-sm">
          <p class="font-bold text-blue-800 mb-2">
            {{ $t('ATMTA_BILLING.MODAL.TRANSFER_TITLE') }}
          </p>
          <ol class="list-decimal list-inside space-y-1 text-blue-700">
            <li>
              {{
                $t('ATMTA_BILLING.MODAL.TRANSFER_STEP_1', {
                  amount: totalEGP,
                  number: selectedPaymentDetails?.number,
                })
              }}
            </li>
            <li>{{ $t('ATMTA_BILLING.MODAL.TRANSFER_STEP_2') }}</li>
            <li>{{ $t('ATMTA_BILLING.MODAL.TRANSFER_STEP_3') }}</li>
            <li>{{ $t('ATMTA_BILLING.MODAL.TRANSFER_STEP_4') }}</li>
          </ol>
        </div>

        <div class="space-y-3">
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1">
              {{ $t('ATMTA_BILLING.MODAL.SENDER_PHONE_LABEL') }}
            </label>
            <input
              v-model="senderPhone"
              type="tel"
              :placeholder="$t('ATMTA_BILLING.MODAL.SENDER_PHONE_PLACEHOLDER')"
              class="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1">
              {{ $t('ATMTA_BILLING.MODAL.REF_LABEL') }}
            </label>
            <input
              v-model="transferRef"
              type="text"
              :placeholder="$t('ATMTA_BILLING.MODAL.REF_PLACEHOLDER')"
              class="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
        </div>

        <ButtonV4
          solid
          blue
          :is-loading="isSubmitting"
          :disabled="!senderPhone || !transferRef"
          class="w-full"
          @click="submitManualPayment"
        >
          {{ $t('ATMTA_BILLING.MODAL.SUBMIT_BTN') }}
        </ButtonV4>
      </div>
    </div>
  </Modal>
</template>
