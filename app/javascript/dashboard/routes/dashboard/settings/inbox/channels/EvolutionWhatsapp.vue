<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { isPhoneE164, shouldBeUrl } from 'shared/helpers/Validators';
import Banner from 'dashboard/components-next/banner/Banner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import EvolutionQrPanel from '../components/EvolutionQrPanel.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const uiFlags = useMapGetter('inboxes/getUIFlags');

const form = reactive({
  inboxName: '',
  phoneNumber: '',
  apiUrl: '',
  apiKey: '',
});

const touched = reactive({
  inboxName: false,
  phoneNumber: false,
  apiUrl: false,
});

const showAdvanced = ref(false);
const errorMessage = ref('');
const createdInbox = ref(null);
const isConnected = ref(false);

const inboxNameError = computed(() => {
  if (!touched.inboxName) return '';
  return form.inboxName.trim()
    ? ''
    : t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.INBOX_NAME_ERROR');
});

const phoneError = computed(() => {
  if (!touched.phoneNumber) return '';
  return isPhoneE164(form.phoneNumber.trim())
    ? ''
    : t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.PHONE_ERROR');
});

const apiUrlError = computed(() => {
  const url = form.apiUrl.trim();
  if (!touched.apiUrl || !url) return '';
  return shouldBeUrl(url)
    ? ''
    : t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.API_URL_ERROR');
});

const isFormValid = computed(() => {
  const url = form.apiUrl.trim();
  return (
    Boolean(form.inboxName.trim()) &&
    isPhoneE164(form.phoneNumber.trim()) &&
    (!url || shouldBeUrl(url))
  );
});

const returnToProviders = () => {
  router.push({
    name: route.name,
    params: route.params,
    query: {},
  });
};

const createChannel = async () => {
  touched.inboxName = true;
  touched.phoneNumber = true;
  touched.apiUrl = true;
  errorMessage.value = '';

  if (!isFormValid.value) return;

  const providerConfig = { source: 'evolution' };
  if (form.apiUrl.trim()) {
    providerConfig.api_url = form.apiUrl.trim().replace(/\/+$/, '');
  }
  if (form.apiKey.trim()) {
    providerConfig.api_key = form.apiKey.trim();
  }

  try {
    const whatsappChannel = await store.dispatch('inboxes/createChannel', {
      name: form.inboxName.trim(),
      channel: {
        type: 'whatsapp',
        phone_number: form.phoneNumber.trim(),
        provider: 'evolution',
        provider_config: providerConfig,
      },
    });
    createdInbox.value = whatsappChannel;
  } catch (error) {
    const message =
      error?.message || t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.CREATE_ERROR');
    errorMessage.value = message;
    useAlert(message);
  }
};

const goToAddAgents = () => {
  if (!createdInbox.value?.id) return;
  router.replace({
    name: 'settings_inboxes_add_agents',
    params: {
      page: 'new',
      inbox_id: createdInbox.value.id,
    },
  });
};
</script>

<template>
  <div v-if="!createdInbox" class="flex flex-col gap-5">
    <div>
      <h2 class="text-heading-2 text-n-slate-12">
        {{ t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.TITLE') }}
      </h2>
      <p class="mt-1 text-body-main text-n-slate-11">
        {{ t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.DESCRIPTION') }}
      </p>
    </div>

    <Banner v-if="errorMessage" color="ruby">
      {{ errorMessage }}
    </Banner>

    <form class="flex flex-col gap-4" @submit.prevent="createChannel">
      <Input
        v-model="form.inboxName"
        :label="t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.INBOX_NAME_LABEL')"
        :placeholder="
          t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.INBOX_NAME_PLACEHOLDER')
        "
        :message="inboxNameError"
        :message-type="inboxNameError ? 'error' : 'info'"
        @blur="touched.inboxName = true"
      />

      <Input
        v-model="form.phoneNumber"
        :label="t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.PHONE_LABEL')"
        :placeholder="t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.PHONE_PLACEHOLDER')"
        :message="phoneError"
        :message-type="phoneError ? 'error' : 'info'"
        @blur="touched.phoneNumber = true"
      />

      <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
        <button
          type="button"
          class="flex w-full items-center justify-between text-start text-sm font-medium text-n-slate-12"
          @click="showAdvanced = !showAdvanced"
        >
          <span class="flex items-center gap-2">
            <Icon icon="i-lucide-sliders-horizontal" class="size-4" />
            <span>
              {{ t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.ADVANCED_TOGGLE') }}
            </span>
          </span>
          <Icon
            :icon="
              showAdvanced ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'
            "
            class="size-4 text-n-slate-10"
          />
        </button>

        <div v-if="showAdvanced" class="mt-4 flex flex-col gap-4">
          <p class="text-label-small text-n-slate-11">
            {{ t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.ADVANCED_HELP') }}
          </p>
          <Input
            v-model="form.apiUrl"
            :label="t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.API_URL_LABEL')"
            :placeholder="
              t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.API_URL_PLACEHOLDER')
            "
            :message="apiUrlError"
            :message-type="apiUrlError ? 'error' : 'info'"
            @blur="touched.apiUrl = true"
          />
          <Input
            v-model="form.apiKey"
            type="password"
            autocomplete="off"
            :label="t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.API_KEY_LABEL')"
            :placeholder="
              t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.API_KEY_PLACEHOLDER')
            "
          />
        </div>
      </div>

      <div
        class="flex items-center justify-between border-t border-n-weak pt-4"
      >
        <Button
          type="button"
          variant="outline"
          color="slate"
          :label="t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.BACK_BUTTON')"
          @click="returnToProviders"
        />
        <Button
          type="submit"
          solid
          blue
          :is-loading="uiFlags.isCreating"
          :disabled="uiFlags.isCreating"
          :label="t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.SUBMIT_BUTTON')"
        />
      </div>
    </form>
  </div>

  <div v-else class="flex flex-col gap-5">
    <div>
      <h2 class="text-heading-2 text-n-slate-12">
        {{ t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.SCAN_STEP_TITLE') }}
      </h2>
      <p class="mt-1 text-body-main text-n-slate-11">
        {{ t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.SCAN_STEP_DESCRIPTION') }}
      </p>
    </div>

    <EvolutionQrPanel
      :inbox="createdInbox"
      auto-fetch-qr
      @connected="isConnected = true"
    />

    <div class="flex justify-end border-t border-n-weak pt-4">
      <Button
        :label="
          isConnected
            ? t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.FINISH_BUTTON')
            : t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.SKIP_TO_AGENTS_BUTTON')
        "
        :color="isConnected ? 'teal' : 'blue'"
        solid
        trailing-icon
        icon="i-lucide-arrow-right"
        @click="goToAddAgents"
      />
    </div>
  </div>
</template>
