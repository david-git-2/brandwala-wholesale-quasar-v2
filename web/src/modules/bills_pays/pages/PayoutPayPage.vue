<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="row items-center q-pb-sm shrink-0">
      <q-btn flat dense no-caps icon="ph ph-arrow-left" label="Payments" @click="goBack" />
    </div>
    <div class="col overflow-auto">
      <div class="pay-form-card q-pa-md q-gutter-y-md">
        <div class="text-subtitle1 text-weight-bold">Pay out — merchant</div>
        <p class="text-caption text-grey-7 q-ma-none">Settles shop cashbook. Not a bill allocation.</p>

        <q-input v-model="search" outlined dense label="Search shop / group" debounce="300" @update:model-value="loadSummary" />

        <q-list bordered separator class="rounded-borders">
          <q-item
            v-for="row in summary"
            :key="row.customer_group_id"
            clickable
            :active="selectedGroupId === row.customer_group_id"
            @click="selectGroup(row)"
          >
            <q-item-section>
              <q-item-label>{{ row.name }}</q-item-label>
              <q-item-label caption>Payable {{ formatAmountBdt(row.payable_balance) }}</q-item-label>
            </q-item-section>
          </q-item>
        </q-list>

        <template v-if="selectedProfile">
          <div class="text-body2">
            Profile: <strong>{{ selectedProfile.name }}</strong> · Balance
            {{ formatAmountBdt(selectedProfile.payable_balance) }}
          </div>
          <q-input v-model.number="amount" outlined dense label="Payout amount" type="number" />
          <q-select v-model="method" :options="methodOptions" emit-value map-options outlined dense label="Method" />
          <q-input v-model="notes" outlined dense label="Notes" type="textarea" autogrow />
          <q-btn
            unelevated
            color="primary"
            no-caps
            label="Pay out"
            :loading="submitting"
            :disable="!canSubmit"
            @click="submit"
          />
        </template>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import { paysRepository, type CustomerGroupPayoutSummary } from '../repositories/paysRepository';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();

const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const search = ref('');
const summary = ref<CustomerGroupPayoutSummary[]>([]);
const selectedGroupId = ref<number | null>(null);
const selectedProfile = ref<{ billing_profile_id: number; name: string; payable_balance: number } | null>(null);

const amount = ref<number | null>(null);
const method = ref('bank_transfer');
const notes = ref('');
const submitting = ref(false);
const methodOptions = [
  { label: 'Bank transfer', value: 'bank_transfer' },
  { label: 'Cash', value: 'cash' },
  { label: 'bKash', value: 'bkash' },
];

const canSubmit = computed(
  () =>
    !!selectedProfile.value &&
    (amount.value ?? 0) > 0 &&
    (amount.value ?? 0) <= (selectedProfile.value?.payable_balance ?? 0),
);

const loadSummary = async () => {
  if (!tenantId.value) return;
  summary.value = await paysRepository.listCustomerGroupsPayoutSummary(tenantId.value, {
    search: search.value,
    onlyWithPayable: true,
  });
};

const selectGroup = (row: CustomerGroupPayoutSummary) => {
  selectedGroupId.value = row.customer_group_id;
  const profiles = row.billing_profiles ?? [];
  selectedProfile.value = profiles[0] ?? null;
  amount.value = selectedProfile.value?.payable_balance ?? null;
};

const goBack = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push({ name: 'app-payments-page', params: tenantSlug ? { tenantSlug } : {} });
};

const submit = async () => {
  if (!selectedProfile.value || !canSubmit.value) return;
  submitting.value = true;
  try {
    await paysRepository.dispenseMiddlemanPayout({
      tenant_id: tenantId.value,
      billing_profile_id: selectedProfile.value.billing_profile_id,
      amount: Number(amount.value),
      payout_method: method.value,
      reference_notes: notes.value || null,
    });
    showSuccessNotification('Payout recorded.');
    goBack();
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : 'Payout failed.');
  } finally {
    submitting.value = false;
  }
};

void loadSummary();
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
}
.pay-form-card {
  max-width: 720px;
  margin: 0 auto;
  background: var(--bw-neutral-surface, #fff);
  border: 1px solid var(--bw-neutral-border, #e7e1d8);
  border-radius: 8px;
}
</style>
