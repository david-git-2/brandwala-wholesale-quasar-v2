<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Shop &amp; Order</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Dropship Operations Desk</h1>
        </div>
        <div class="col-auto row q-gutter-sm">
          <q-btn
            outline
            color="primary"
            icon="local_shipping"
            label="Courier Catalog"
            no-caps
            :to="{ name: 'app-shop-dropship-couriers-page' }"
          />
          <q-btn
            outline
            color="secondary"
            icon="storefront"
            label="Merchants & Pickup"
            no-caps
            :to="{ name: 'app-shop-dropship-merchants-page' }"
          />
          <q-btn
            outline
            color="secondary"
            icon="account_balance_wallet"
            label="Payout Ledger"
            no-caps
            :to="{ name: 'app-shop-dropship-ledger-page' }"
          />
        </div>
      </section>

      <!-- Filters & Search Toolbar -->
      <q-card flat bordered class="form-card q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-md">
          <div class="col-12 col-sm-6 col-md-4">
            <q-input
              v-model="searchQuery"
              dense
              outlined
              hide-bottom-space
              placeholder="Search order no, recipient, phone, AWB..."
              clearable
              debounce="300"
              @update:model-value="onSearchChange"
            >
              <template #prepend>
                <q-icon name="search" />
              </template>
            </q-input>
          </div>

          <div class="col-12 col-sm-6 col-md-auto row q-gutter-xs items-center">
            <q-chip
              v-for="st in statusOptions"
              :key="st.val"
              clickable
              :outline="selectedStatus !== st.val"
              :color="selectedStatus === st.val ? 'primary' : 'grey-4'"
              :text-color="selectedStatus === st.val ? 'white' : 'grey-9'"
              @click="onSelectStatus(st.val)"
            >
              {{ st.label }} ({{ getCountForStatus(st.val) }})
            </q-chip>
          </div>
        </div>
      </q-card>

      <!-- Orders Table Card -->
      <q-card flat bordered class="form-card">
        <div v-if="loading" class="row justify-center q-py-xl">
          <q-spinner color="primary" size="3em" />
        </div>
        <q-markup-table v-else flat borderless class="q-mb-none soft-table">
          <thead>
            <tr>
              <th class="text-left">Order No</th>
              <th class="text-left">Middle Man</th>
              <th class="text-left">Recipient</th>
              <th class="text-left">Courier</th>
              <th class="text-left">AWB</th>
              <th class="text-left">Status</th>
              <th class="text-right">COD Collect</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="filteredOrders.length === 0">
              <td colspan="8" class="text-center text-grey-7 q-py-xl">
                <q-icon name="inbox" size="36px" class="text-grey-4 q-mb-xs" />
                <div>No dropship consignments found for this filter.</div>
              </td>
            </tr>
            <tr v-for="c in filteredOrders" :key="c.id" class="hover-row">
              <td>
                <router-link
                  class="text-weight-bold text-primary text-decoration-none"
                  :to="{ name: 'app-shop-dropship-order-detail-page', params: { id: c.id } }"
                >
                  {{ c.order_no }}
                </router-link>
                <div class="text-caption text-grey-6">{{ formatDate(c.created_at) }}</div>
              </td>
              <td>
                <div class="text-weight-medium text-grey-9">
                  {{ c.customer_group_name || c.created_by_email || '—' }}
                </div>
              </td>
              <td>
                <div class="text-weight-medium text-grey-9">{{ c.recipient_name || '—' }}</div>
                <div class="text-caption text-grey-7">{{ c.recipient_phone || '—' }}</div>
              </td>
              <td>
                <div class="text-weight-medium text-grey-9">{{ c.courier_name || 'Not Selected' }}</div>
              </td>
              <td>
                <div v-if="c.courier_awb_number" class="text-caption text-primary" style="font-family: monospace">
                  {{ c.courier_awb_number }}
                </div>
                <div v-else class="text-caption text-grey-5">—</div>
              </td>
              <td>
                <q-chip dense :color="getStatusColor(c.status)" text-color="white" size="sm">
                  {{ c.status.toUpperCase().replace(/_/g, ' ') }}
                </q-chip>
              </td>
              <td class="text-right text-weight-bold text-grey-9">
                {{ formatAmount(c.cod_collect_amount ?? c.total_amount ?? 0) }} BDT
              </td>
              <td class="text-right">
                <div class="row reverse q-gutter-xs justify-end items-center no-wrap">
                  <q-btn
                    color="primary"
                    unelevated
                    dense
                    size="sm"
                    no-caps
                    label="Process"
                    :to="{ name: 'app-shop-dropship-order-detail-page', params: { id: c.id } }"
                  />
                  <q-btn
                    v-if="c.status === 'shipped'"
                    color="positive"
                    outline
                    dense
                    size="sm"
                    no-caps
                    label="Mark Delivered"
                    :loading="actionOrderId === c.id && actionKind === 'deliver'"
                    @click="markDelivered(c)"
                  />
                  <q-btn
                    v-if="canCreateAccountingInvoice(c)"
                    color="positive"
                    outline
                    dense
                    size="sm"
                    no-caps
                    label="Create Accounting Invoice"
                    :loading="actionOrderId === c.id && actionKind === 'invoice'"
                    @click="createAccountingInvoice(c)"
                  />
                  <q-btn
                    v-if="canRecordRemittance(c)"
                    color="primary"
                    outline
                    dense
                    size="sm"
                    no-caps
                    label="Record Remittance"
                    @click="openRemittanceDialog(c)"
                  />
                  <q-btn
                    v-if="canSettlePayout(c)"
                    color="positive"
                    outline
                    dense
                    size="sm"
                    no-caps
                    label="Settle Payout"
                    :loading="actionOrderId === c.id && actionKind === 'settle'"
                    @click="settlePayout(c)"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card>
    </section>

    <q-dialog v-model="remittanceDialogOpen" persistent>
      <q-card style="min-width: 440px; border-radius: 12px">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6 text-weight-bold">Record Courier Remittance</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-card-section class="q-gutter-sm">
          <div class="text-body2 text-grey-8">
            Order <strong>{{ remittanceOrder?.order_no }}</strong> — net COD collection from courier.
          </div>
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
            label="Notes"
            outlined
            dense
            type="textarea"
            autogrow
          />
        </q-card-section>
        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="Cancel" v-close-popup no-caps />
          <q-btn
            color="primary"
            unelevated
            label="Save Remittance"
            no-caps
            :disable="!canSaveRemittance"
            :loading="actionKind === 'remit'"
            @click="saveRemittance"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, reactive, onMounted } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { supabase } from 'src/boot/supabase';
import {
  showSuccessNotification,
  showErrorNotification,
  requestConfirmation,
} from 'src/utils/appFeedback';
import { shopOrderService } from '../services/shopOrderService';
import { dropshipLedgerService } from '../services/dropshipLedgerService';
import type { ShopOrder } from '../types';

const authStore = useAuthStore();
const loading = ref(false);
const orders = ref<ShopOrder[]>([]);
const searchQuery = ref('');
const selectedStatus = ref<string>('all');

const actionOrderId = ref<number | null>(null);
const actionKind = ref<'deliver' | 'invoice' | 'remit' | 'settle' | null>(null);

const remittanceDialogOpen = ref(false);
const remittanceOrder = ref<ShopOrder | null>(null);
const remittanceForm = reactive({
  remittance_ref: '',
  net_amount: 0,
  bank_trx_id: '',
  note: '',
});

const INVOICE_ELIGIBLE = ['ready_for_pickup', 'shipped', 'delivered', 'payment_received'];
const SETTLE_ELIGIBLE = ['delivered', 'payment_received'];

const statusOptions = [
  { label: 'All Orders', val: 'all' },
  { label: 'Processing', val: 'processing' },
  { label: 'Ready for Pickup', val: 'ready_for_pickup' },
  { label: 'Shipped', val: 'shipped' },
  { label: 'Delivered', val: 'delivered' },
  { label: 'Returned', val: 'returned' },
];

const loadOrders = async () => {
  if (!authStore.tenantId) return;
  loading.value = true;
  try {
    const res = await shopOrderService.fetchDropshipStaffOrders(authStore.tenantId, {
      limit: 200,
      status: null,
      search: searchQuery.value.trim() || null,
    });
    orders.value = res.success && res.data ? res.data : [];
    if (!res.success && res.error) {
      showErrorNotification(res.error);
    }
  } catch (err) {
    console.error('Failed to load dropship orders:', err);
    showErrorNotification('Failed to load dropship orders.');
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  void loadOrders();
});

const onSelectStatus = (status: string) => {
  selectedStatus.value = status;
};

const onSearchChange = () => {
  void loadOrders();
};

const filteredOrders = computed(() => {
  if (selectedStatus.value === 'all') return orders.value;
  return orders.value.filter((c) => c.status === selectedStatus.value);
});

const getCountForStatus = (val: string) => {
  if (val === 'all') return orders.value.length;
  return orders.value.filter((c) => c.status === val).length;
};

const canCreateAccountingInvoice = (c: ShopOrder) =>
  INVOICE_ELIGIBLE.includes(c.status) && !c.global_invoice_id;

const canRecordRemittance = (c: ShopOrder) =>
  c.status === 'delivered' && !!c.global_invoice_id && !c.courier_remittance_ref;

const canSettlePayout = (c: ShopOrder) =>
  SETTLE_ELIGIBLE.includes(c.status) && !!c.global_invoice_id;

const canSaveRemittance = computed(
  () =>
    remittanceForm.remittance_ref.trim().length > 0 &&
    Number(remittanceForm.net_amount) > 0 &&
    !!remittanceOrder.value,
);

const markDelivered = async (c: ShopOrder) => {
  const ok = await requestConfirmation(
    `Mark order ${c.order_no} as collected / delivered?`,
    'Mark Delivered',
    'Mark Delivered',
  );
  if (!ok) return;

  actionOrderId.value = c.id;
  actionKind.value = 'deliver';
  try {
    const { data, error } = await supabase.rpc('advance_dropship_order_status', {
      p_order_id: c.id,
      p_target_status: 'delivered',
    });
    if (error) throw error;
    const res = data as { success?: boolean; error?: string } | null;
    if (res && typeof res === 'object' && res.success === false) {
      throw new Error(res.error || 'Failed to update status');
    }
    showSuccessNotification(`Order ${c.order_no} marked delivered.`);
    await loadOrders();
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to mark delivered');
  } finally {
    actionOrderId.value = null;
    actionKind.value = null;
  }
};

const createAccountingInvoice = async (c: ShopOrder) => {
  const ok = await requestConfirmation(
    `Create accounting invoice for order ${c.order_no}? This posts books and links global_invoice_id.`,
    'Create Accounting Invoice',
    'Post Invoice',
  );
  if (!ok) return;

  actionOrderId.value = c.id;
  actionKind.value = 'invoice';
  try {
    const { data, error } = await supabase.rpc('create_dual_invoice_from_dropship_order', {
      p_order_id: c.id,
      p_invoice_no: null,
      p_billing_profile_id: null,
      p_note: `Accounting invoice created from dropship order #${c.order_no}`,
    });
    if (error) throw error;
    const res = data as { invoice_no?: string } | null;
    showSuccessNotification(
      `Accounting invoice${res?.invoice_no ? ` #${res.invoice_no}` : ''} created for ${c.order_no}.`,
    );
    await loadOrders();
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to create accounting invoice');
  } finally {
    actionOrderId.value = null;
    actionKind.value = null;
  }
};

const openRemittanceDialog = (c: ShopOrder) => {
  remittanceOrder.value = c;
  remittanceForm.remittance_ref = '';
  remittanceForm.net_amount = Number(c.cod_collect_amount ?? 0);
  remittanceForm.bank_trx_id = '';
  remittanceForm.note = '';
  remittanceDialogOpen.value = true;
};

const saveRemittance = async () => {
  if (!canSaveRemittance.value || !remittanceOrder.value || !authStore.tenantId) return;

  actionKind.value = 'remit';
  try {
    const res = await dropshipLedgerService.recordRemittance({
      order_id: remittanceOrder.value.id,
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
    await loadOrders();
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to record remittance');
  } finally {
    actionKind.value = null;
  }
};

const settlePayout = async (c: ShopOrder) => {
  if (!authStore.tenantId || !c.global_invoice_id) return;

  const ok = await requestConfirmation(
    `Settle middle-man payout for order ${c.order_no}?`,
    'Settle Payout',
    'Settle',
  );
  if (!ok) return;

  actionOrderId.value = c.id;
  actionKind.value = 'settle';
  try {
    const res = await dropshipLedgerService.settlePayoutForInvoice(
      authStore.tenantId,
      c.global_invoice_id,
      c.order_no,
    );
    if (!res.success) {
      showErrorNotification(res.error || 'Failed to settle payout');
      return;
    }
    showSuccessNotification(`Payout settled for order ${c.order_no}.`);
    await loadOrders();
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to settle payout');
  } finally {
    actionOrderId.value = null;
    actionKind.value = null;
  }
};

const getStatusColor = (status: string) => {
  switch (status) {
    case 'processing':
      return 'orange-8';
    case 'ready_for_pickup':
      return 'blue-7';
    case 'shipped':
      return 'purple-7';
    case 'delivered':
      return 'positive';
    case 'returned':
      return 'negative';
    default:
      return 'grey';
  }
};

const formatDate = (isoStr: string) => new Date(isoStr).toLocaleDateString();

const formatAmount = (n: number | null | undefined) =>
  Number(n || 0).toLocaleString(undefined, {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  });
</script>
