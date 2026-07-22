<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Shop &amp; Order / Dropship</div>
          <h1 class="text-h5 q-my-none">Middle-Man Payout &amp; COD Remittance Ledger</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Track middle-man profit credits, return fee deductions, courier COD collections, and payout settlements.
          </p>
        </div>
        <div class="col-auto row q-gutter-sm">
          <q-btn
            color="primary"
            icon="account_balance"
            label="Record Courier Remittance"
            no-caps
            class="pill-btn"
            :disable="!tenantId"
            @click="openRemittanceDialog"
          />
        </div>
      </section>

      <div class="row q-col-gutter-md">
        <div class="col-12 col-sm-4">
          <q-card flat bordered class="q-pa-md rounded-borders">
            <div class="text-caption text-grey-7">Total Unsettled Profit Balance</div>
            <div class="text-h6 text-weight-bold text-positive">
              {{ formatAmount(totalUnsettledBalance) }} BDT
            </div>
          </q-card>
        </div>
        <div class="col-12 col-sm-4">
          <q-card flat bordered class="q-pa-md rounded-borders">
            <div class="text-caption text-grey-7">Pending Courier COD Remittance</div>
            <div class="text-h6 text-weight-bold text-primary">
              {{ formatAmount(pendingCodTotal) }} BDT
            </div>
          </q-card>
        </div>
        <div class="col-12 col-sm-4">
          <q-card flat bordered class="q-pa-md rounded-borders">
            <div class="text-caption text-grey-7">Settled Payouts This Month</div>
            <div class="text-h6 text-weight-bold text-grey-8">
              {{ formatAmount(settledThisMonth) }} BDT
            </div>
          </q-card>
        </div>
      </div>

      <q-card flat bordered class="form-card">
        <q-markup-table flat borderless class="q-mb-none soft-table">
          <thead>
            <tr>
              <th class="text-left">Date</th>
              <th class="text-left">Order No</th>
              <th class="text-left">Transaction Type</th>
              <th class="text-left">Remittance Ref</th>
              <th class="text-right">Amount</th>
              <th class="text-right">Running Balance</th>
              <th class="text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="ledgerQuery.isLoading.value">
              <td colspan="7" class="text-center text-grey-7 q-py-xl">
                <q-spinner color="primary" size="28px" />
              </td>
            </tr>
            <tr v-else-if="ledgerEntries.length === 0">
              <td colspan="7" class="text-center text-grey-7 q-py-xl">
                <q-icon name="receipt" size="36px" class="text-grey-4 q-mb-xs" />
                <div>No ledger entries found.</div>
              </td>
            </tr>
            <tr v-for="l in ledgerEntries" :key="l.id" class="hover-row">
              <td>{{ formatDate(l.created_at) }}</td>
              <td class="text-weight-bold text-primary">
                {{ l.shop_orders?.order_no || l.shop_order_id || '—' }}
              </td>
              <td>
                <q-chip
                  dense
                  :color="l.amount >= 0 ? 'green-1' : 'red-1'"
                  :text-color="l.amount >= 0 ? 'positive' : 'negative'"
                  size="sm"
                >
                  {{ l.entry_type.toUpperCase().replace(/_/g, ' ') }}
                </q-chip>
              </td>
              <td>
                <span class="text-caption text-grey-7">{{ l.reference_notes || '—' }}</span>
              </td>
              <td
                class="text-right text-weight-bold"
                :class="l.amount >= 0 ? 'text-positive' : 'text-negative'"
              >
                {{ l.amount >= 0 ? '+' : '' }}{{ formatAmount(l.amount) }} BDT
              </td>
              <td class="text-right text-weight-bold text-grey-9">
                {{ formatAmount(l.balance_after) }} BDT
              </td>
              <td class="text-right">
                <q-btn
                  v-if="canSettle(l)"
                  color="positive"
                  outline
                  size="sm"
                  no-caps
                  label="Settle Payout"
                  :loading="settlingId === l.id"
                  @click="settlePayout(l)"
                />
                <q-chip
                  v-else
                  dense
                  color="grey-2"
                  text-color="grey-7"
                  size="sm"
                >
                  {{ l.entry_type === 'payout_paid' ? 'Settled' : 'Recorded' }}
                </q-chip>
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card>

      <q-dialog v-model="remittanceDialogOpen" persistent>
        <q-card style="min-width: 440px; border-radius: 12px">
          <q-card-section class="row items-center justify-between">
            <div class="text-h6 text-weight-bold">Record Courier Remittance</div>
            <q-btn flat round dense icon="close" v-close-popup />
          </q-card-section>
          <q-card-section class="q-gutter-sm">
            <q-select
              v-model="remittanceForm.order_id"
              :options="remittanceOrderOptions"
              emit-value
              map-options
              label="Delivered Order *"
              outlined
              dense
              :loading="remittanceOrdersQuery.isFetching.value"
              @update:model-value="onRemittanceOrderChange"
            />
            <q-input
              v-model="remittanceForm.remittance_ref"
              label="Remittance Batch / Statement ID *"
              outlined
              dense
            />
            <q-input
              v-model.number="remittanceForm.net_amount"
              type="number"
              label="Net Remitted Amount (BDT) *"
              outlined
              dense
            />
            <q-input
              v-model="remittanceForm.bank_trx_id"
              label="Bank / MFS Transaction ID"
              outlined
              dense
            />
            <q-input
              v-model="remittanceForm.note"
              label="Remittance Notes"
              outlined
              dense
              type="textarea"
              rows="2"
            />
          </q-card-section>
          <q-card-actions align="right" class="q-pa-md">
            <q-btn flat label="Cancel" v-close-popup />
            <q-btn
              color="primary"
              label="Save Remittance"
              :loading="savingRemittance"
              :disable="!canSaveRemittance"
              @click="saveRemittance"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { dropshipLedgerService } from '../services/dropshipLedgerService';
import { shopOrderQueryKeys } from '../services/shopOrderQueryKeys';
import type { PayoutLedgerRow } from '../repositories/dropshipLedgerRepository';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

const authStore = useAuthStore();
const route = useRoute();
const queryClient = useQueryClient();

const tenantId = computed(() => authStore.tenantId);
const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null,
);

const remittanceDialogOpen = ref(false);
const savingRemittance = ref(false);
const settlingId = ref<string | null>(null);

const remittanceForm = reactive({
  order_id: null as number | null,
  remittance_ref: '',
  net_amount: 0,
  bank_trx_id: '',
  note: '',
});

const ledgerQuery = useQuery({
  queryKey: computed(() => shopOrderQueryKeys.ledger(tenantSlug.value)),
  enabled: computed(() => !!tenantId.value),
  staleTime: 15_000,
  queryFn: async () => {
    const id = tenantId.value;
    if (!id) return [];
    const res = await dropshipLedgerService.fetchLedgerEntries(id);
    if (!res.success) throw new Error(res.error || 'Failed to load ledger');
    return res.data ?? [];
  },
});

const pendingCodQuery = useQuery({
  queryKey: computed(() => shopOrderQueryKeys.ledgerPendingCod(tenantSlug.value)),
  enabled: computed(() => !!tenantId.value),
  staleTime: 30_000,
  queryFn: async () => {
    const id = tenantId.value;
    if (!id) return 0;
    const res = await dropshipLedgerService.fetchPendingCodTotal(id);
    if (!res.success) throw new Error(res.error || 'Failed to load pending COD');
    return res.data ?? 0;
  },
});

const remittanceOrdersQuery = useQuery({
  queryKey: computed(() => shopOrderQueryKeys.ledgerRemittanceOrders(tenantSlug.value)),
  enabled: computed(() => !!tenantId.value && remittanceDialogOpen.value),
  staleTime: 15_000,
  queryFn: async () => {
    const id = tenantId.value;
    if (!id) return [];
    const res = await dropshipLedgerService.fetchDeliveredOrdersForRemittance(id);
    if (!res.success) throw new Error(res.error || 'Failed to load orders');
    return res.data ?? [];
  },
});

const ledgerEntries = computed(() => ledgerQuery.data.value ?? []);
const pendingCodTotal = computed(() => pendingCodQuery.data.value ?? 0);

const paidInvoiceIds = computed(() => {
  const ids = new Set<number>();
  for (const entry of ledgerEntries.value) {
    if (entry.entry_type === 'payout_paid' && entry.global_invoice_id != null) {
      ids.add(entry.global_invoice_id);
    }
  }
  return ids;
});

const totalUnsettledBalance = computed(() => {
  const latestByMember = new Map<number, PayoutLedgerRow>();
  for (const entry of ledgerEntries.value) {
    if (!latestByMember.has(entry.customer_group_member_id)) {
      latestByMember.set(entry.customer_group_member_id, entry);
    }
  }
  let sum = 0;
  for (const entry of latestByMember.values()) {
    sum += Number(entry.balance_after ?? 0);
  }
  return sum;
});

const settledThisMonth = computed(() => {
  const now = new Date();
  const y = now.getFullYear();
  const m = now.getMonth();
  return ledgerEntries.value
    .filter((e) => e.entry_type === 'payout_paid')
    .filter((e) => {
      const d = new Date(e.created_at);
      return d.getFullYear() === y && d.getMonth() === m;
    })
    .reduce((sum, e) => sum + Math.abs(Number(e.amount ?? 0)), 0);
});

const remittanceOrderOptions = computed(() =>
  (remittanceOrdersQuery.data.value ?? []).map((o) => ({
    label: `${o.order_no} — COD ${formatAmount(o.cod_collect_amount ?? 0)} BDT`,
    value: o.id,
  })),
);

const canSaveRemittance = computed(
  () =>
    !!remittanceForm.order_id &&
    remittanceForm.remittance_ref.trim().length > 0 &&
    Number(remittanceForm.net_amount) > 0,
);

const canSettle = (l: PayoutLedgerRow) =>
  l.entry_type === 'profit_credit' &&
  l.global_invoice_id != null &&
  !paidInvoiceIds.value.has(l.global_invoice_id);

const invalidateLedgerQueries = async () => {
  await Promise.all([
    queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.ledger(tenantSlug.value) }),
    queryClient.invalidateQueries({
      queryKey: shopOrderQueryKeys.ledgerPendingCod(tenantSlug.value),
    }),
    queryClient.invalidateQueries({
      queryKey: shopOrderQueryKeys.ledgerRemittanceOrders(tenantSlug.value),
    }),
  ]);
};

const openRemittanceDialog = () => {
  remittanceForm.order_id = null;
  remittanceForm.remittance_ref = '';
  remittanceForm.net_amount = 0;
  remittanceForm.bank_trx_id = '';
  remittanceForm.note = '';
  remittanceDialogOpen.value = true;
};

const onRemittanceOrderChange = (orderId: number | null) => {
  const order = (remittanceOrdersQuery.data.value ?? []).find((o) => o.id === orderId);
  remittanceForm.net_amount = Number(order?.cod_collect_amount ?? 0);
};

const saveRemittance = async () => {
  if (!canSaveRemittance.value || !remittanceForm.order_id) return;
  savingRemittance.value = true;
  try {
    const res = await dropshipLedgerService.recordRemittance({
      order_id: remittanceForm.order_id,
      net_amount: Number(remittanceForm.net_amount),
      remittance_ref: remittanceForm.remittance_ref.trim(),
      bank_trx_id: remittanceForm.bank_trx_id.trim() || null,
      note: remittanceForm.note.trim() || null,
    });
    if (!res.success) {
      showErrorNotification(res.error || 'Failed to record remittance');
      return;
    }
    showSuccessNotification(`Remittance ${remittanceForm.remittance_ref.trim()} recorded.`);
    remittanceDialogOpen.value = false;
    await invalidateLedgerQueries();
  } finally {
    savingRemittance.value = false;
  }
};

const settlePayout = async (l: PayoutLedgerRow) => {
  const id = tenantId.value;
  if (!id || !canSettle(l)) return;
  settlingId.value = l.id;
  try {
    const res = await dropshipLedgerService.settlePayoutForLedgerEntry(id, l);
    if (!res.success) {
      showErrorNotification(res.error || 'Failed to settle payout');
      return;
    }
    showSuccessNotification(
      `Payout settled for order #${l.shop_orders?.order_no || l.shop_order_id}.`,
    );
    await invalidateLedgerQueries();
  } finally {
    settlingId.value = null;
  }
};

const formatDate = (isoStr: string) => new Date(isoStr).toLocaleDateString();
const formatAmount = (n: number | null | undefined) =>
  Number(n || 0).toLocaleString(undefined, {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  });
</script>
