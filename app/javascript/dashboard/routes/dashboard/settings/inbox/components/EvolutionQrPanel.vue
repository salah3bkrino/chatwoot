<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useTimeoutPoll } from '@vueuse/core';
import whatsappChannel from 'dashboard/api/channel/whatsappChannel';
import { useAlert } from 'dashboard/composables';
import Banner from 'dashboard/components-next/banner/Banner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
  autoFetchQr: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['connected', 'statusChange']);

const { t } = useI18n();

const POLL_INTERVAL_MS = 3000;
const QR_REFRESH_TICKS = 15;

const connectionState = ref('unknown');
const qrBase64 = ref('');
const pairingCode = ref('');
const errorMessage = ref('');
const isLoadingStatus = ref(false);
const isFetchingQr = ref(false);
const isReconnecting = ref(false);
const isDisconnecting = ref(false);
const pollTicks = ref(0);

const isConnected = computed(() => connectionState.value === 'open');
const isConnecting = computed(() => connectionState.value === 'connecting');
const secondsUntilRefresh = computed(() =>
  Math.max(0, (QR_REFRESH_TICKS - pollTicks.value) * (POLL_INTERVAL_MS / 1000))
);

const instanceName = computed(
  () => props.inbox?.provider_config?.instance_name || ''
);

const statusBadge = computed(() => {
  if (isConnected.value) {
    return {
      label: t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.STATUS_OPEN'),
      classes: 'bg-n-teal-3 text-n-teal-11 border-n-teal-5',
      icon: 'i-lucide-check-circle-2',
    };
  }
  if (isConnecting.value) {
    return {
      label: t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.STATUS_CONNECTING'),
      classes: 'bg-n-amber-3 text-n-amber-11 border-n-amber-5',
      icon: 'i-lucide-qr-code',
    };
  }
  if (connectionState.value === 'close') {
    return {
      label: t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.STATUS_CLOSE'),
      classes: 'bg-n-ruby-3 text-n-ruby-11 border-n-ruby-5',
      icon: 'i-lucide-wifi-off',
    };
  }
  return {
    label: t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.STATUS_UNKNOWN'),
    classes: 'bg-n-slate-3 text-n-slate-11 border-n-weak',
    icon: 'i-lucide-loader-circle',
  };
});

const extractApiError = (error, fallbackKey) =>
  error?.response?.data?.error || error?.message || t(fallbackKey);

const updateState = nextState => {
  connectionState.value = nextState || 'close';
  emit('statusChange', connectionState.value);
  if (connectionState.value === 'open') {
    qrBase64.value = '';
    pairingCode.value = '';
    emit('connected');
  }
};

let pausePolling = () => {};
let resumePolling = () => {};

const fetchQrCode = async () => {
  if (!props.inbox?.id) return;
  isFetchingQr.value = true;
  errorMessage.value = '';
  try {
    const { data } = await whatsappChannel.getEvolutionQR(props.inbox.id);
    qrBase64.value = data.base64 || '';
    pairingCode.value = data.pairing_code || '';
    pollTicks.value = 0;
    updateState(data.state || (qrBase64.value ? 'connecting' : 'close'));
    if (connectionState.value === 'open') {
      pausePolling();
    } else {
      resumePolling();
    }
  } catch (error) {
    errorMessage.value = extractApiError(
      error,
      'INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.QR_ERROR'
    );
  } finally {
    isFetchingQr.value = false;
  }
};

const fetchStatus = async ({ silent = false } = {}) => {
  if (!props.inbox?.id) return;
  if (!silent) isLoadingStatus.value = true;
  try {
    const { data } = await whatsappChannel.getEvolutionStatus(props.inbox.id);
    updateState(data.state);
    if (connectionState.value === 'open') {
      pausePolling();
    }
  } catch (error) {
    if (!silent) {
      errorMessage.value = extractApiError(
        error,
        'INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.STATUS_ERROR'
      );
    }
  } finally {
    if (!silent) isLoadingStatus.value = false;
  }
};

const pollControls = useTimeoutPoll(
  async () => {
    await fetchStatus({ silent: true });
    if (isConnected.value) return;

    pollTicks.value += 1;
    if (qrBase64.value && pollTicks.value >= QR_REFRESH_TICKS) {
      await fetchQrCode();
    }
  },
  POLL_INTERVAL_MS,
  { immediate: false }
);

pausePolling = pollControls.pause;
resumePolling = pollControls.resume;

const restartConnection = async () => {
  if (!props.inbox?.id) return;
  isReconnecting.value = true;
  errorMessage.value = '';
  try {
    const { data } = await whatsappChannel.reconnectEvolution(props.inbox.id);
    updateState(data.state || 'connecting');
    useAlert(t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.RESTART_SUCCESS'));
    if (!isConnected.value) {
      await fetchQrCode();
    }
  } catch (error) {
    errorMessage.value = extractApiError(
      error,
      'INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.RESTART_ERROR'
    );
    useAlert(errorMessage.value);
  } finally {
    isReconnecting.value = false;
  }
};

const disconnectSession = async () => {
  if (!props.inbox?.id) return;
  isDisconnecting.value = true;
  errorMessage.value = '';
  try {
    await whatsappChannel.disconnectEvolution(props.inbox.id);
    pausePolling();
    qrBase64.value = '';
    pairingCode.value = '';
    updateState('close');
    useAlert(t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.DISCONNECT_SUCCESS'));
  } catch (error) {
    errorMessage.value = extractApiError(
      error,
      'INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.DISCONNECT_ERROR'
    );
    useAlert(errorMessage.value);
  } finally {
    isDisconnecting.value = false;
  }
};

const initializePanel = async () => {
  pausePolling();
  qrBase64.value = '';
  pairingCode.value = '';
  errorMessage.value = '';
  await fetchStatus();
  if (!isConnected.value && props.autoFetchQr) {
    await fetchQrCode();
  }
};

watch(
  () => props.inbox?.id,
  (newId, oldId) => {
    if (newId && newId !== oldId) {
      initializePanel();
    }
  }
);

onMounted(() => {
  initializePanel();
});
</script>

<template>
  <div
    class="flex flex-col gap-5 rounded-2xl border border-n-weak bg-n-surface-2 p-6"
  >
    <div
      class="flex flex-wrap items-start justify-between gap-4 border-b border-n-weak pb-4"
    >
      <div class="min-w-0 flex-1">
        <h3 class="text-heading-2 text-n-slate-12">
          {{ t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.TITLE') }}
        </h3>
        <p class="mt-1 text-body-main text-n-slate-11">
          {{ t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.DESCRIPTION') }}
        </p>
      </div>
      <div
        class="inline-flex items-center gap-2 rounded-full border px-3 py-1 text-label-small font-medium"
        :class="statusBadge.classes"
      >
        <Icon :icon="statusBadge.icon" class="size-4" />
        <span>{{ statusBadge.label }}</span>
      </div>
    </div>

    <div
      v-if="inbox.phone_number || instanceName"
      class="grid gap-3 rounded-xl border border-n-weak bg-n-solid-1 p-4 sm:grid-cols-2"
    >
      <div v-if="inbox.phone_number" class="flex flex-col gap-0.5">
        <span class="text-label-small text-n-slate-10">
          {{ t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.PHONE_LABEL') }}
        </span>
        <span class="font-mono text-sm font-medium text-n-slate-12">
          {{ inbox.phone_number }}
        </span>
      </div>
      <div v-if="instanceName" class="flex flex-col gap-0.5">
        <span class="text-label-small text-n-slate-10">
          {{ t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.INSTANCE_LABEL') }}
        </span>
        <span class="font-mono text-sm font-medium text-n-slate-12">
          {{ instanceName }}
        </span>
      </div>
    </div>

    <Banner v-if="errorMessage" color="ruby">
      {{ errorMessage }}
    </Banner>

    <Banner v-if="isConnected" color="teal">
      <div class="flex items-center gap-2 font-medium">
        <Icon icon="i-lucide-check-circle-2" class="size-4 flex-shrink-0" />
        <span>
          {{ t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.CONNECTED_BANNER') }}
        </span>
      </div>
    </Banner>

    <div
      v-else-if="isFetchingQr || isLoadingStatus"
      class="flex flex-col items-center justify-center gap-3 rounded-xl border border-dashed border-n-weak bg-n-solid-1 p-10"
    >
      <Spinner :size="32" class="text-n-brand" />
      <p class="text-body-main text-n-slate-11">
        {{ t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.STATUS_UNKNOWN') }}
      </p>
    </div>

    <div
      v-else-if="qrBase64"
      class="flex flex-col items-center gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-6 text-center"
    >
      <img
        :src="qrBase64"
        :alt="t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.QR_ALT')"
        class="size-64 rounded-xl border border-n-weak bg-white p-3 object-contain"
      />
      <div v-if="pairingCode" class="flex flex-col items-center gap-1">
        <span class="text-label-small text-n-slate-10">
          {{ t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.PAIRING_CODE_LABEL') }}
        </span>
        <code
          class="rounded-lg bg-n-alpha-2 px-3 py-1 font-mono text-base font-semibold tracking-widest text-n-slate-12"
        >
          {{ pairingCode }}
        </code>
      </div>
      <p class="max-w-md text-body-main text-n-slate-11">
        {{ t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.QR_INSTRUCTIONS') }}
      </p>
      <p class="text-label-small text-n-slate-10">
        {{
          t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.AUTO_REFRESH_HINT', {
            seconds: secondsUntilRefresh,
          })
        }}
      </p>
    </div>

    <div class="flex flex-wrap items-center gap-3 pt-1">
      <Button
        v-if="!isConnected"
        :label="
          qrBase64
            ? t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.REFRESH_QR_BUTTON')
            : t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.GENERATE_QR_BUTTON')
        "
        icon="i-lucide-qr-code"
        solid
        blue
        :is-loading="isFetchingQr"
        :disabled="isFetchingQr || isReconnecting || isDisconnecting"
        @click="fetchQrCode"
      />
      <Button
        :label="t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.RESTART_BUTTON')"
        icon="i-lucide-refresh-cw"
        variant="outline"
        color="slate"
        :is-loading="isReconnecting"
        :disabled="isFetchingQr || isReconnecting || isDisconnecting"
        @click="restartConnection"
      />
      <Button
        v-if="isConnected"
        :label="t('INBOX_MGMT.SETTINGS_POPUP.EVOLUTION.DISCONNECT_BUTTON')"
        icon="i-lucide-log-out"
        variant="outline"
        color="ruby"
        :is-loading="isDisconnecting"
        :disabled="isFetchingQr || isReconnecting || isDisconnecting"
        @click="disconnectSession"
      />
    </div>
  </div>
</template>
