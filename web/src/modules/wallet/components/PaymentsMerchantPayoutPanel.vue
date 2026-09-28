<template>
  <div class="column col no-wrap overflow-hidden payout-panel">
    <div class="q-px-xs q-pt-none q-pb-xs flex-shrink-0">
      <div class="text-subtitle2 text-weight-bold text-primary row items-center gap-xs">
        <q-icon name="ph ph-hand-coins" size="18px" />
        <span>Groups owed (merchant wallet)</span>
      </div>
      <div class="text-caption text-grey-7">
        Tap a row to pay out from tenant cash.
      </div>
    </div>

    <div class="col column no-wrap overflow-hidden payout-panel__body relative-position">
      <q-inner-loading :showing="isGroupsLoading" color="primary">
        <q-spinner-dots size="32px" />
      </q-inner-loading>

      <div
        v-if="!isGroupsLoading && payableGroups.length === 0"
        class="payout-panel__empty text-grey-6"
      >
        No customer groups have a merchant wallet balance right now.
      </div>

      <q-scroll-area v-else class="col">
        <q-list bordered separator class="payout-group-list">
          <q-item
            v-for="group in payableGroups"
            :key="group.customer_group_id"
            v-ripple
            clickable
            class="payout-group-list__item"
            @click="openGroup(group)"
          >
            <q-item-section avatar>
              <q-avatar color="primary" text-color="white" size="40px" font-size="14px">
                {{ groupInitials(group.name) }}
              </q-avatar>
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-weight-medium">{{ group.name }}</q-item-label>
              <q-item-label caption>{{ group.account_code }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <div class="text-right">
                <div class="text-2xs text-grey-6 text-uppercase">Tenant owes</div>
                <div class="text-subtitle2 text-weight-bold text-positive font-mono">
                  ৳{{ formatCurrency(group.payable_balance) }}
                </div>
              </div>
              <q-icon name="ph ph-caret-right" size="18px" class="text-grey-5 q-ml-sm" />
            </q-item-section>
          </q-item>
        </q-list>
      </q-scroll-area>
    </div>

    <q-drawer
      v-model="payoutDrawerOpen"
      side="right"
      overlay
      elevated
      :width="520"
      class="merchant-payout-drawer"
    >
      <div class="column full-height">
        <div class="row items-center justify-between q-pa-md bg-grey-1 border-bottom">
          <div>
            <div class="text-subtitle1 text-weight-bold row items-center">
              <q-icon name="ph ph-hand-coins" class="q-mr-xs text-primary" size="20px" />
              Merchant payout
            </div>
            <div v-if="selectedGroup" class="text-caption text-grey-7">
              {{ selectedGroup.name }}
              <span v-if="selectedGroup.account_code"> · {{ selectedGroup.account_code }}</span>
            </div>
          </div>
          <q-btn
            icon="ph ph-x"
            flat
            round
            dense
            aria-label="Close payout panel"
            @click="closePayoutDrawer"
          />
        </div>

        <div class="col scroll q-pa-md">
          <q-form v-if="selectedGroup" class="q-gutter-y-md" @submit.prevent="handleSubmit">
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
                <q-card flat bordered class="q-pa-sm bg-grey-1">
                  <div class="text-caption text-grey-8">Parent tenant cash (available to pay)</div>
                  <div class="text-h6 text-weight-bold font-mono">
                    ৳{{ formatCurrency(tenantCashBalance) }}
                  </div>
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
              Payout wallet:
              <span class="text-weight-medium">{{ payableProfiles[0].name }}</span>
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

            <div class="row justify-end q-pt-sm">
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
          </q-form>
        </div>
      </div>
    </q-drawer>
  </div>
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
  onlyWithPayable?: boolean;
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

const payoutDrawerOpen = ref(false);
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
      ? [...financeReportQueryKeys.root, 'payout-groups', props.tenantId, props.onlyWithPayable ?? true] as const
      : financeReportQueryKeys.root,
  ),
  queryFn: () =>
    paymentsRepository.listCustomerGroupsPayoutSummary({
      tenantId: props.tenantId || 0,
      limit: 200,
      onlyWithPayable: props.onlyWithPayable ?? true,
    }),
  enabled: computed(() => Boolean(props.tenantId && props.tenantId > 0)),
  staleTime: 30_000,
});

const isGroupsLoading = computed(() => groupsQuery.isLoading.value);

const groups = computed(() => groupsQuery.data.value ?? []);

const payableGroups = computed(() => groups.value);

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

function groupInitials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

function applyGroupSelection(group: CustomerGroupPayoutSummary) {
  const profiles = group.billing_profiles.filter((p) => Number(p.payable_balance) > 0);
  const preferred =
    profiles.find((p) => p.billing_profile_id === props.preselectedBillingProfileId)
    ?? profiles[0]
    ?? group.billing_profiles[0];
  billingProfileId.value = preferred?.billing_profile_id ?? null;
  const bal = preferred ? Number(preferred.payable_balance) : Number(group.payable_balance);
  const cap = Math.min(bal, props.tenantCashBalance || 0);
  amount.value = cap > 0 ? cap : 0;
  referenceNotes.value = '';
}

function openGroup(group: CustomerGroupPayoutSummary) {
  selectedGroupId.value = group.customer_group_id;
  applyGroupSelection(group);
  payoutDrawerOpen.value = true;
}

function closePayoutDrawer() {
  payoutDrawerOpen.value = false;
}

async function refreshGroups() {
  await groupsQuery.refetch();
}

defineExpose({
  closePayoutDrawer,
  refreshGroups,
});

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
    onlyWithPayable: false,
  });
  if (rows.length > 0) {
    openGroup(rows[0]);
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

<style scoped>
.payout-panel {
  min-height: 0;
  background: transparent;
}

.payout-panel__body {
  min-height: 0;
}

.payout-panel__empty {
  padding: 2rem 1rem;
  text-align: center;
  border: 1px dashed var(--bw-neutral-border, #e2e8f0);
  border-radius: 8px;
  background: transparent;
}

.payout-group-list {
  background: var(--bw-theme-surface, #fff);
  border-radius: 8px;
}

.payout-group-list__item {
  min-height: 64px;
}

.border-bottom {
  border-bottom: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.08));
}

.merchant-payout-drawer :deep(.q-drawer__content) {
  background: var(--bw-theme-surface, #fff);
}
</style>
