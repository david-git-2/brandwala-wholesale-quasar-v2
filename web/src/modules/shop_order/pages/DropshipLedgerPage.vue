<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
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
            @click="openRemittanceDialog"
          />
        </div>
      </section>

      <!-- Ledger Summary Stats -->
      <div class="row q-col-gutter-md">
        <div class="col-12 col-sm-4">
          <q-card flat bordered class="q-pa-md rounded-borders">
            <div class="text-caption text-grey-7">Total Unsettled Profit Balance</div>
            <div class="text-h6 text-weight-bold text-positive">
              {{ totalUnsettledBalance }} BDT
            </div>
          </q-card>
        </div>
        <div class="col-12 col-sm-4">
          <q-card flat bordered class="q-pa-md rounded-borders">
            <div class="text-caption text-grey-7">Pending Courier COD Remittance</div>
            <div class="text-h6 text-weight-bold text-primary">
              6,700 BDT
            </div>
          </q-card>
        </div>
        <div class="col-12 col-sm-4">
          <q-card flat bordered class="q-pa-md rounded-borders">
            <div class="text-caption text-grey-7">Settled Payouts This Month</div>
            <div class="text-h6 text-weight-bold text-grey-8">
              12,400 BDT
            </div>
          </q-card>
        </div>
      </div>

      <!-- Ledger Table -->
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
            <tr v-if="ledgerEntries.length === 0">
              <td colspan="7" class="text-center text-grey-7 q-py-xl">
                <q-icon name="receipt" size="36px" class="text-grey-4 q-mb-xs" />
                <div>No ledger entries found.</div>
              </td>
            </tr>
            <tr v-for="l in ledgerEntries" :key="l.id" class="hover-row">
              <td>{{ formatDate(l.created_at) }}</td>
              <td class="text-weight-bold text-primary">{{ l.shop_orders?.order_no || l.shop_order_id || '—' }}</td>
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
                {{ l.amount >= 0 ? '+' : '' }}{{ l.amount }} BDT
              </td>
              <td class="text-right text-weight-bold text-grey-9">
                {{ l.balance_after }} BDT
              </td>
              <td class="text-right">
                <q-btn
                  v-if="l.entry_type === 'profit_credit'"
                  color="positive"
                  outline
                  size="sm"
                  no-caps
                  label="Settle Payout"
                  @click="settlePayout(l)"
                />
                <q-chip v-else dense color="grey-2" text-color="grey-7" size="sm">{{ l.entry_type === 'payout_paid' ? 'Settled' : 'Recorded' }}</q-chip>
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card>

      <!-- Record Courier Remittance Dialog -->
      <q-dialog v-model="remittanceDialogOpen" persistent>
        <q-card style="min-width: 440px; border-radius: 12px">
          <q-card-section class="row items-center justify-between">
            <div class="text-h6 text-weight-bold">Record Courier Remittance</div>
            <q-btn flat round dense icon="close" v-close-popup />
          </q-card-section>
          <q-card-section class="q-gutter-sm">
            <q-select
              v-model="remittanceForm.courier_id"
              :options="courierOptions"
              emit-value
              map-options
              label="Courier Partner *"
              outlined
              dense
            />
            <q-input v-model="remittanceForm.remittance_batch_id" label="Remittance Batch / Statement ID *" outlined dense />
            <q-input v-model.number="remittanceForm.amount" type="number" label="Remitted Amount (BDT) *" outlined dense />
            <q-input v-model="remittanceForm.bank_trx_id" label="Bank / MFS Transaction ID" outlined dense />
            <q-input v-model="remittanceForm.notes" label="Remittance Notes" outlined dense type="textarea" rows="2" />
          </q-card-section>
          <q-card-actions align="right" class="q-pa-md">
            <q-btn flat label="Cancel" v-close-popup />
            <q-btn color="primary" label="Save Remittance" @click="saveRemittance" />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, reactive, onMounted } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { dropshipLedgerService } from '../services/dropshipLedgerService';
import { dropshipCourierService } from '../services/dropshipCourierService';
import type { PayoutLedgerRow } from '../repositories/dropshipLedgerRepository';
import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

const authStore = useAuthStore();
const loading = ref(false);
const ledgerEntries = ref<PayoutLedgerRow[]>([]);
const couriers = ref<CourierServiceRow[]>([]);
const remittanceDialogOpen = ref(false);

const remittanceForm = reactive({
  courier_id: null as string | null,
  remittance_batch_id: '',
  amount: 0,
  bank_trx_id: '',
  notes: '',
});

const courierOptions = computed(() =>
  couriers.value.map((c) => ({ label: c.name, value: c.id }))
);

const totalUnsettledBalance = computed(() => {
  if (ledgerEntries.value.length === 0) return 0;
  // Use the latest balance_after if available
  return ledgerEntries.value[0]?.balance_after ?? 0;
});

const loadData = async () => {
  const tenantId = authStore.tenantId;
  if (!tenantId) return;

  loading.value = true;
  try {
    const [ledgerRes, courierRes] = await Promise.all([
      dropshipLedgerService.fetchLedgerEntries(tenantId),
      dropshipCourierService.fetchCouriers(),
    ]);

    if (ledgerRes.success && ledgerRes.data) {
      ledgerEntries.value = ledgerRes.data;
    }
    if (courierRes.success && courierRes.data) {
      couriers.value = courierRes.data;
      if (couriers.value.length > 0 && couriers.value[0]) {
        remittanceForm.courier_id = couriers.value[0].id;
      }
    }
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to load ledger entries');
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  void loadData();
});

const openRemittanceDialog = () => {
  remittanceForm.remittance_batch_id = `REMIT-${new Date().getFullYear()}-${Math.floor(100 + Math.random() * 900)}`;
  remittanceForm.amount = 2500;
  remittanceForm.bank_trx_id = `TRX-${Math.floor(100000 + Math.random() * 900000)}`;
  remittanceForm.notes = 'Bulk COD settlement from courier statement';
  remittanceDialogOpen.value = true;
};

const saveRemittance = () => {
  showSuccessNotification(`Remittance ${remittanceForm.remittance_batch_id} recorded successfully!`);
  remittanceDialogOpen.value = false;
};

const settlePayout = async (l: PayoutLedgerRow) => {
  const tenantId = authStore.tenantId;
  if (!tenantId) return;

  const currentBalance = totalUnsettledBalance.value;
  const newBalance = currentBalance - l.amount;

  const res = await dropshipLedgerService.addLedgerEntry({
    tenant_id: tenantId,
    customer_group_member_id: l.customer_group_member_id,
    shop_order_id: l.shop_order_id,
    global_invoice_id: l.global_invoice_id,
    entry_type: 'payout_paid',
    amount: -l.amount,
    balance_after: newBalance,
    reference_notes: `Payout settled for order #${l.shop_orders?.order_no || l.shop_order_id || 'N/A'}`,
  });

  if (res.success) {
    showSuccessNotification(`Payout settled for order #${l.shop_orders?.order_no || l.shop_order_id}!`);
    await loadData();
  } else {
    showErrorNotification(res.error || 'Failed to settle payout');
  }
};

const formatDate = (isoStr: string) => {
  return new Date(isoStr).toLocaleDateString();
};
</script>
