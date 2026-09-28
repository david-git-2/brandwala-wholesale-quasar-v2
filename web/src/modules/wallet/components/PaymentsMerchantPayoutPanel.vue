<template>
  <q-card flat bordered class="q-pa-md">
    <div class="text-subtitle1 text-weight-bold text-primary q-mb-md row items-center gap-xs">
      <q-icon name="ph ph-hand-coins" size="20px" />
      <span>Merchant payout (customer group)</span>
    </div>

    <q-form class="q-gutter-y-md" @submit.prevent="handleSubmit">
      <q-select
        v-model="selectedGroupId"
        :options="groupOptions"
        option-value="customer_group_id"
        option-label="label"
        emit-value
        map-options
        use-input
        fill-input
        hide-selected
        input-debounce="300"
        outlined
        dense
        label="Search customer group"
        :loading="isGroupsLoading"
        @filter="onFilterGroups"
        @update:model-value="onGroupSelected"
      >
        <template #no-option>
          <q-item>
            <q-item-section class="text-grey-6">
              {{ isGroupsLoading ? 'Loading…' : 'No customer groups match your search' }}
            </q-item-section>
          </q-item>
        </template>
        <template #option="scope">
          <q-item v-bind="scope.itemProps">
            <q-item-section>
              <q-item-label>{{ scope.opt.name }}</q-item-label>
              <q-item-label caption>{{ scope.opt.account_code }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-item-label class="text-positive text-weight-bold font-mono">
                ৳{{ formatCurrency(scope.opt.payable_balance) }}
              </q-item-label>
            </q-item-section>
          </q-item>
        </template>
      </q-select>

      <q-banner
        v-if="selectedGroup && selectedGroup.payable_balance <= 0"
        class="bg-grey-2 text-grey-8 rounded-borders"
        dense
      >
        This customer group has no merchant wallet balance available for payout.
      </q-banner>

      <template v-else-if="selectedGroup">
        <div class="row q-col-gutter-md">
          <div class="col-12 col-sm-6">
            <q-card flat bordered class="q-pa-sm bg-green-1">
              <div class="text-caption text-grey-8">Tenant owes this group (wallet)</div>
              <div class="text-h6 text-weight-bold text-positive font-mono">
                ৳{{ formatCurrency(selectedGroup.payable_balance) }}
              </div>
            </q-card>
          </div>
          <div class="col-12 col-sm-6">
            <q-card flat bordered class="q-pa-sm">
              <div class="text-caption text-grey-8">Parent tenant cash (available to pay)</div>
              <div class="text-h6 text-weight-bold font-mono">৳{{ formatCurrency(tenantCashBalance) }}</div>
            </q-card>
          </div>
        </div>

        <q-select
          v-if="payableProfiles.length > 1"
          v-model="billingProfileId"
          :options="payableProfiles"
          option-value="billing_profile_id"
          option-label="label"
          emit-value
          map-options
          outlined
          dense
          label="Billing profile (wallet)"
          :rules="[(v) => !!v || 'Select a billing profile']"
        />

        <div v-else-if="payableProfiles.length === 1" class="text-caption text-grey-7">
          Payout wallet: <span class="text-weight-medium">{{ payableProfiles[0].name }}</span>
        </div>

        <div class="row q-col-gutter-sm">
          <div class="col-12 col-md-6">
            <q-input
              v-model.number="amount"
              type="number"
              label="Payout amount (BDT)"
              outlined
              dense
              step="0.01"
              :max="maxPayoutAmount"
              :rules="[
                (v) => v > 0 || 'Must be greater than 0',
                (v) => v <= maxPayoutAmount || `Max ${formatCurrency(maxPayoutAmount)}`,
              ]"
            />
          </div>
          <div class="col-12 col-md-6">
            <q-select
              v-model="payoutMethod"
              :options="payoutMethodOptions"
              label="Payout method"
              outlined
              dense
              emit-value
              map-options
            />
          </div>
        </div>

        <q-input
          v-model="referenceNotes"
          label="Reference / bank trx ID"
          outlined
          dense
        />

        <div class="row justify-end">
          <q-btn
            type="submit"
            color="primary"
            unelevated
            no-caps
            :loading="loading"
            :disable="!canSubmit"
            label="Pay out from tenant cash"
          />
        </div>
      </template>
    </q-form>
  </q-card>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { paymentsRepository } from '../repositories/paymentsRepository';
import { financeReportQueryKeys } from 'src/modules/reporting_treasury/shared/queryKeys';
import type { CustomerGroupPayoutSummary } from '../types/paymentsTypes';

const props = defineProps<{
  tenantId: number | null;
  tenantCashBalance: number;
  preselectedCustomerGroupId?: number | null;
  preselectedBillingProfileId?: number | null;
  loading: boolean;
}>();

const emit = defineEmits<{
  (
    e: 'submit',
    payload: {
      billingProfileId: number;
      amount: number;
      payoutMethod?: string;
      referenceNotes?: string;
    },
  ): void;
}>();

const searchText = ref('');
const selectedGroupId = ref<number | null>(null);
const billingProfileId = ref<number | null>(null);
const amount = ref(0);
const payoutMethod = ref('bank_transfer');
const referenceNotes = ref('');

const payoutMethodOptions = [
  { label: 'Bank transfer', value: 'bank_transfer' },
  { label: 'bKash / mobile wallet', value: 'bkash' },
  { label: 'Cash', value: 'cash' },
];

const groupsQuery = useQuery({
  queryKey: computed(() =>
    props.tenantId
      ? [...financeReportQueryKeys.root, 'payout-groups', props.tenantId, searchText.value] as const
      : financeReportQueryKeys.root,
  ),
  queryFn: () =>
    paymentsRepository.listCustomerGroupsPayoutSummary({
      tenantId: props.tenantId || 0,
      search: searchText.value || null,
      limit: 50,
    }),
  enabled: computed(() => Boolean(props.tenantId && props.tenantId > 0)),
  staleTime: 30_000,
});

const isGroupsLoading = computed(() => groupsQuery.isLoading.value);

const groups = computed(() => groupsQuery.data.value ?? []);

const groupOptions = computed(() =>
  groups.value.map((g) => ({
    ...g,
    label: `${g.name} · ৳${formatCurrency(g.payable_balance)}`,
  })),
);

const selectedGroup = computed(() =>
  groups.value.find((g) => g.customer_group_id === selectedGroupId.value) ?? null,
);

const payableProfiles = computed(() => {
  const profiles = selectedGroup.value?.billing_profiles ?? [];
  return profiles
    .filter((p) => Number(p.payable_balance) > 0)
    .map((p) => ({
      ...p,
      label: `${p.name} (৳${formatCurrency(p.payable_balance)})`,
    }));
});

const selectedProfileBalance = computed(() => {
  if (!billingProfileId.value) return 0;
  const p = payableProfiles.value.find((x) => x.billing_profile_id === billingProfileId.value);
  return p ? Number(p.payable_balance) : 0;
});

const maxPayoutAmount = computed(() => {
  const walletCap = selectedProfileBalance.value || selectedGroup.value?.payable_balance || 0;
  const cash = props.tenantCashBalance || 0;
  return Math.max(0, Math.min(walletCap, cash));
});

const canSubmit = computed(
  () =>
    Boolean(billingProfileId.value)
    && amount.value > 0
    && amount.value <= maxPayoutAmount.value
    && !props.loading,
);

function formatCurrency(val: number) {
  return Number(val || 0).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function onFilterGroups(val: string, update: (fn: () => void) => void) {
  update(() => {
    searchText.value = val;
  });
}

function applyGroupSelection(group: CustomerGroupPayoutSummary | null) {
  if (!group) {
    billingProfileId.value = null;
    amount.value = 0;
    return;
  }
  const profiles = group.billing_profiles.filter((p) => Number(p.payable_balance) > 0);
  const preferred =
    profiles.find((p) => p.billing_profile_id === props.preselectedBillingProfileId)
    ?? profiles[0]
    ?? group.billing_profiles[0];
  billingProfileId.value = preferred?.billing_profile_id ?? null;
  const bal = preferred ? Number(preferred.payable_balance) : Number(group.payable_balance);
  const cap = Math.min(bal, props.tenantCashBalance || 0);
  amount.value = cap > 0 ? cap : 0;
}

function onGroupSelected(id: number | null) {
  const group = groups.value.find((g) => g.customer_group_id === id) ?? null;
  applyGroupSelection(group);
}

watch(payableProfiles, (profiles) => {
  if (!billingProfileId.value && profiles.length === 1) {
    billingProfileId.value = profiles[0].billing_profile_id;
  }
});

watch(
  () => billingProfileId.value,
  (id) => {
    if (!id) return;
    const p = payableProfiles.value.find((x) => x.billing_profile_id === id);
    if (p && amount.value === 0) {
      amount.value = Math.min(Number(p.payable_balance), props.tenantCashBalance || 0);
    }
  },
);

async function loadPreselectedGroup() {
  if (!props.tenantId || !props.preselectedCustomerGroupId) return;
  const rows = await paymentsRepository.listCustomerGroupsPayoutSummary({
    tenantId: props.tenantId,
    customerGroupId: props.preselectedCustomerGroupId,
    limit: 1,
  });
  if (rows.length > 0) {
    selectedGroupId.value = rows[0].customer_group_id;
    applyGroupSelection(rows[0]);
  }
}

watch(
  () => [props.preselectedCustomerGroupId, props.tenantId] as const,
  () => {
    void loadPreselectedGroup();
  },
  { immediate: true },
);

function handleSubmit() {
  if (!billingProfileId.value || amount.value <= 0) return;
  emit('submit', {
    billingProfileId: billingProfileId.value,
    amount: amount.value,
    payoutMethod: payoutMethod.value,
    referenceNotes: referenceNotes.value,
  });
}
</script>
