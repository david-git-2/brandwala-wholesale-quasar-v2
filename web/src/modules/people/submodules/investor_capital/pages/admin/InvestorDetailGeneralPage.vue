<template>
  <div class="full-height overflow-auto bg-surface q-pa-md">
    <div v-if="loadingInvestors" class="text-grey-7">Loading profile…</div>

    <q-banner v-else-if="!investor" class="bg-warning text-dark" rounded>
      Investor not found.
    </q-banner>

    <template v-else>
      <div class="row q-col-gutter-md q-mb-lg">
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered class="q-pa-md">
            <div class="text-caption text-grey-7">Available</div>
            <div class="text-h6 text-primary">{{ formatAmount(investor.available_balance) }}</div>
          </q-card>
        </div>
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered class="q-pa-md">
            <div class="text-caption text-grey-7">Deployed</div>
            <div class="text-h6">{{ formatAmount(investor.total_invested_active) }}</div>
          </q-card>
        </div>
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered class="q-pa-md">
            <div class="text-caption text-grey-7">Capital in</div>
            <div class="text-h6">{{ formatAmount(investor.total_capital_in) }}</div>
          </q-card>
        </div>
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered class="q-pa-md">
            <div class="text-caption text-grey-7">Withdrawn</div>
            <div class="text-h6">{{ formatAmount(investor.total_withdrawn) }}</div>
          </q-card>
        </div>
      </div>

      <q-card flat bordered class="q-pa-md">
        <div class="row items-center justify-between q-mb-md q-gutter-sm">
          <div class="text-subtitle2 text-weight-bold">Profile</div>
          <div class="row items-center q-gutter-sm">
            <span v-if="saving" class="text-caption text-grey-7">Saving…</span>
            <q-btn
              outline
              no-caps
              color="primary"
              icon="ph ph-copy"
              label="Copy investor login link"
              :disable="!investorLoginUrl"
              @click="copyInvestorLoginUrl"
            />
          </div>
        </div>

        <div class="row q-col-gutter-md">
          <div class="col-12 col-md-6">
            <div class="text-caption text-grey-7 q-mb-xs">Name</div>
            <q-input
              v-model="form.name"
              outlined
              dense
              :loading="saving"
              @blur="saveOnBlur"
              @keyup.enter="($event.target as HTMLInputElement)?.blur()"
            />
          </div>
          <div class="col-12 col-md-6">
            <div class="text-caption text-grey-7 q-mb-xs">Phone</div>
            <q-input
              v-model="form.phone"
              outlined
              dense
              :loading="saving"
              @blur="saveOnBlur"
              @keyup.enter="($event.target as HTMLInputElement)?.blur()"
            />
          </div>
          <div class="col-12 col-md-6">
            <div class="text-caption text-grey-7 q-mb-xs">Email</div>
            <q-input
              v-model="form.email"
              outlined
              dense
              :loading="saving"
              @blur="saveOnBlur"
              @keyup.enter="($event.target as HTMLInputElement)?.blur()"
            />
          </div>
          <div class="col-12 col-md-6">
            <div class="text-caption text-grey-7 q-mb-xs">Currency</div>
            <q-input
              v-model="form.currency_code"
              outlined
              dense
              placeholder="BDT"
              :loading="saving"
              @blur="saveOnBlur"
              @keyup.enter="($event.target as HTMLInputElement)?.blur()"
            />
          </div>
          <div class="col-12">
            <div class="text-caption text-grey-7 q-mb-xs">Address</div>
            <q-input
              v-model="form.address"
              outlined
              dense
              type="textarea"
              autogrow
              :loading="saving"
              @blur="saveOnBlur"
            />
          </div>
          <div class="col-12 col-md-6">
            <div class="text-caption text-grey-7 q-mb-xs">Status</div>
            <q-toggle
              v-model="form.is_active"
              color="primary"
              label="Profile active"
              :disable="saving"
              @update:model-value="saveOnBlur"
            />
          </div>
          <div class="col-12">
            <div class="text-caption text-grey-7 q-mb-xs">Notes</div>
            <q-input
              v-model="form.notes"
              outlined
              dense
              type="textarea"
              autogrow
              :loading="saving"
              @blur="saveOnBlur"
            />
          </div>
        </div>
      </q-card>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue';
import { copyToClipboard } from 'quasar';
import { storeToRefs } from 'pinia';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { useInvestorDetailContext } from '../../composables/useInvestorDetailContext';
import { useInvestorCapitalStore } from '../../stores/investorCapitalStore';
import type { InvestorBalance, InvestorUpdateInput } from '../../types';
import { formatAmountBdt } from 'src/utils/currency';

type ProfileForm = {
  name: string;
  phone: string;
  email: string;
  address: string;
  currency_code: string;
  is_active: boolean;
  notes: string;
};

const capitalStore = useInvestorCapitalStore();
const authStore = useAuthStore();
const { saving } = storeToRefs(capitalStore);
const { investor, tenantId, loadingInvestors } = useInvestorDetailContext();

const baseUrl = computed(() => (typeof window === 'undefined' ? '' : window.location.origin));

const investorLoginUrl = computed(() => {
  const slug = authStore.tenantSlug;
  if (!slug) {
    return `${baseUrl.value}/investor/login`;
  }
  return `${baseUrl.value}/${slug}/investor/login`;
});

const copyInvestorLoginUrl = async () => {
  const url = investorLoginUrl.value;
  if (!url) {
    return;
  }

  try {
    await copyToClipboard(url);
    showSuccessNotification('Investor login link copied');
  } catch (err) {
    console.error(err);
    showErrorNotification('Could not copy link');
  }
};

const form = reactive<ProfileForm>({
  name: '',
  phone: '',
  email: '',
  address: '',
  currency_code: 'BDT',
  is_active: true,
  notes: '',
});

const syncFormFromInvestor = (row: InvestorBalance | null) => {
  if (!row) {
    return;
  }

  form.name = row.name;
  form.phone = row.phone ?? '';
  form.email = row.email ?? '';
  form.address = row.address ?? '';
  form.currency_code = row.currency_code || 'BDT';
  form.is_active = row.is_active;
  form.notes = row.notes ?? '';
};

watch(investor, syncFormFromInvestor, { immediate: true });

const formatAmount = (value: number) => formatAmountBdt(value);

const normalize = (value: string) => value.trim();

const profileMatchesStore = (): boolean => {
  const row = investor.value;
  if (!row) {
    return true;
  }

  return (
    form.name.trim() === row.name &&
    normalize(form.phone) === (row.phone ?? '') &&
    normalize(form.email) === (row.email ?? '') &&
    normalize(form.address) === (row.address ?? '') &&
    normalize(form.currency_code || 'BDT') === (row.currency_code || 'BDT') &&
    form.is_active === row.is_active &&
    normalize(form.notes) === (row.notes ?? '')
  );
};

const buildUpdatePayload = (): InvestorUpdateInput | null => {
  const row = investor.value;
  const tid = tenantId.value;

  if (!row || tid <= 0) {
    return null;
  }

  const name = form.name.trim();
  if (!name) {
    syncFormFromInvestor(row);
    return null;
  }

  return {
    id: row.investor_id,
    tenant_id: tid,
    name,
    phone: normalize(form.phone) || null,
    email: normalize(form.email) || null,
    address: normalize(form.address) || null,
    is_active: form.is_active,
    currency_code: normalize(form.currency_code) || 'BDT',
    notes: normalize(form.notes) || null,
  };
};

const saveOnBlur = async () => {
  if (profileMatchesStore()) {
    return;
  }

  const payload = buildUpdatePayload();
  if (!payload) {
    return;
  }

  const result = await capitalStore.updateInvestor(payload, { notify: false });
  if (!result?.success) {
    syncFormFromInvestor(investor.value);
  }
};
</script>
