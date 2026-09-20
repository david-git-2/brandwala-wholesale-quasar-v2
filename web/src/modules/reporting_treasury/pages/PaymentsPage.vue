<template>
  <q-page class="q-pa-xs page-fixed-layout column no-wrap overflow-hidden payments-page">
    <!-- 1. Unified Compact 38px Toolbar -->
    <q-card flat bordered class="q-pa-xs flex-shrink-0 q-mb-xs">
      <div class="row items-center justify-between q-col-gutter-xs no-wrap">
        <!-- Left: Segmented Filter Tabs & Status Filter -->
        <div class="col-auto row items-center q-gutter-x-xs no-wrap">
          <div class="row items-center q-gutter-x-2xs quick-filter-toggle">
            <q-btn
              v-for="tab in viewTabs"
              :key="tab.value"
              dense
              unelevated
              no-caps
              :color="paymentMode === tab.value ? 'primary' : 'transparent'"
              :text-color="paymentMode === tab.value ? 'white' : 'grey-8'"
              class="quick-filter-btn"
              @click="paymentMode = tab.value"
            >
              <q-icon :name="tab.icon" size="14px" class="q-mr-xs" />
              <span>{{ tab.label }}</span>
            </q-btn>
          </div>

          <q-separator vertical class="q-mx-2xs" />

          <!-- Quick Status Filter (For Invoices View) -->
          <q-select
            v-if="paymentMode === 'invoice'"
            v-model="invoiceStatusFilter"
            :options="statusOptions"
            outlined
            dense
            emit-value
            map-options
            options-dense
            style="min-width: 120px"
            class="dense-filter-select"
          >
            <template #prepend>
              <q-icon name="ph ph-funnel" size="14px" class="text-grey-6" />
            </template>
          </q-select>
        </div>

        <!-- Right: Search Input + Refresh -->
        <div class="col-grow row items-center justify-end q-gutter-x-xs no-wrap">
          <q-input
            v-model="searchQuery"
            outlined
            rounded
            dense
            clearable
            style="min-width: 260px; max-width: 360px"
            class="col-grow col-sm-auto dense-search-input"
            :placeholder="paymentMode === 'customer' ? 'Search customer, group, outlet...' : 'Search invoice no, outlet, phone...'"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" size="16px" class="text-grey-5" />
            </template>
          </q-input>

          <q-btn
            flat
            round
            dense
            icon="ph ph-arrow-clockwise"
            color="grey-7"
            @click="refetchAll"
          >
            <q-tooltip>Refresh</q-tooltip>
          </q-btn>
        </div>
      </div>
    </q-card>

    <!-- ======================================================================= -->
    <!-- VIEW A: CUSTOMER GROUPS LIST TABLE                                      -->
    <!-- ======================================================================= -->
    <div v-if="paymentMode === 'customer'" class="table-container col column no-wrap overflow-hidden">
      <q-table
        flat
        bordered
        dense
        :rows="customerGroups"
        :columns="customerColumns"
        row-key="id"
        :loading="isCustomerGroupsLoading"
        class="treasury-ops-table full-height"
        :pagination="{ rowsPerPage: 25 }"
      >
        <template #loading>
          <q-inner-loading showing color="primary">
            <q-spinner-dots size="32px" />
          </q-inner-loading>
        </template>

        <template #no-data>
          <div class="full-width row flex-center text-grey-6 q-py-lg">
            <q-icon name="ph ph-users-three" size="28px" class="q-mr-xs" />
            <span>No customer groups found with outstanding dues.</span>
          </div>
        </template>

        <!-- Customer Column -->
        <template #body-cell-customer="props">
          <q-td :props="props">
            <div class="row items-center q-gutter-xs no-wrap">
              <q-avatar size="24px" color="grey-3" text-color="grey-9" square class="rounded-avatar">
                <q-icon name="ph ph-buildings" size="13px" />
              </q-avatar>
              <div>
                <div class="text-weight-bold text-primary">{{ props.row.name }}</div>
                <div class="text-2xs text-grey-6 font-mono">{{ props.row.account_code }}</div>
              </div>
            </div>
          </q-td>
        </template>

        <!-- Outlets Column -->
        <template #body-cell-branches="props">
          <q-td :props="props" class="text-grey-8">
            {{ props.row.branches?.length ? props.row.branches.join(' • ') : '—' }}
          </q-td>
        </template>

        <!-- Open Invoices Count Badge -->
        <template #body-cell-invoices="props">
          <q-td :props="props" class="text-center font-mono">
            <q-badge color="grey-2" text-color="grey-9" class="text-weight-bold status-chip">
              {{ props.row.open_invoice_count }} Open
            </q-badge>
          </q-td>
        </template>

        <!-- Total Invoiced -->
        <template #body-cell-total="props">
          <q-td :props="props" class="text-right font-mono text-grey-7">
            ৳{{ formatCurrency(props.row.total_invoiced) }}
          </q-td>
        </template>

        <!-- Paid So Far -->
        <template #body-cell-paid="props">
          <q-td :props="props" class="text-right font-mono text-positive">
            {{ props.row.total_paid > 0 ? '৳' + formatCurrency(props.row.total_paid) : '—' }}
          </q-td>
        </template>

        <!-- Total Outstanding Due -->
        <template #body-cell-due="props">
          <q-td :props="props" class="text-right font-mono text-weight-bold text-negative">
            ৳{{ formatCurrency(props.row.total_due) }}
          </q-td>
        </template>

        <!-- Actions Column -->
        <template #body-cell-actions="props">
          <q-td :props="props" class="text-right">
            <div class="row items-center justify-end q-gutter-x-xs no-wrap">
              <q-btn
                flat
                size="sm"
                color="grey-7"
                icon="ph ph-clock-counter-clockwise"
                label="History"
                no-caps
                class="rounded-btn"
                @click="openHistory(props.row)"
              />
              <q-btn
                unelevated
                size="sm"
                color="primary"
                icon="ph ph-credit-card"
                label="Settle Dues"
                no-caps
                class="rounded-btn text-weight-medium"
                @click="goCollectGroup(props.row)"
              />
            </div>
          </q-td>
        </template>
      </q-table>
    </div>

    <!-- ======================================================================= -->
    <!-- VIEW B: ALL OPEN INVOICES LIST TABLE                                    -->
    <!-- ======================================================================= -->
    <div v-else class="table-container col column no-wrap overflow-hidden">
      <q-table
        flat
        bordered
        dense
        :rows="filteredInvoices"
        :columns="invoiceColumns"
        row-key="id"
        :loading="isOpenInvoicesLoading"
        class="treasury-ops-table full-height"
        :pagination="{ rowsPerPage: 25 }"
      >
        <template #loading>
          <q-inner-loading showing color="primary">
            <q-spinner-dots size="32px" />
          </q-inner-loading>
        </template>

        <template #no-data>
          <div class="full-width row flex-center text-grey-6 q-py-lg">
            <q-icon name="ph ph-receipt" size="28px" class="q-mr-xs" />
            <span>No open due invoices found.</span>
          </div>
        </template>

        <!-- Invoice No Column -->
        <template #body-cell-invoice_no="props">
          <q-td :props="props" :class="getRowStatusClass(props.row)">
            <div class="row items-center q-gutter-2xs no-wrap">
              <span class="font-mono text-weight-bold text-primary">{{ props.row.invoice_no }}</span>
              <q-badge color="grey-2" text-color="grey-8" class="text-2xs text-uppercase" style="border-radius: 4px">
                {{ props.row.invoice_type }}
              </q-badge>
            </div>
          </q-td>
        </template>

        <!-- Outlet Column -->
        <template #body-cell-outlet="props">
          <q-td :props="props">
            <div class="text-weight-medium text-grey-9">{{ props.row.customer_group_name }}</div>
            <div class="text-2xs text-grey-6">{{ props.row.branch_name }}</div>
          </q-td>
        </template>

        <!-- Dates Column -->
        <template #body-cell-date="props">
          <q-td :props="props" class="font-mono text-grey-7">
            {{ props.row.invoice_date }}
          </q-td>
        </template>

        <!-- Due Date Column -->
        <template #body-cell-due_date="props">
          <q-td :props="props" class="font-mono" :class="isOverdue(props.row.due_date) ? 'text-negative text-weight-bold' : 'text-grey-7'">
            {{ props.row.due_date || '—' }}
          </q-td>
        </template>

        <!-- Total Column -->
        <template #body-cell-total="props">
          <q-td :props="props" class="text-right font-mono text-grey-8">
            ৳{{ formatCurrency(props.row.total_amount) }}
          </q-td>
        </template>

        <!-- Paid Column -->
        <template #body-cell-paid="props">
          <q-td :props="props" class="text-right font-mono text-positive">
            {{ props.row.paid_amount > 0 ? '৳' + formatCurrency(props.row.paid_amount) : '—' }}
          </q-td>
        </template>

        <!-- Due Balance Column -->
        <template #body-cell-due="props">
          <q-td :props="props" class="text-right font-mono text-weight-bold text-negative">
            ৳{{ formatCurrency(props.row.due_amount) }}
          </q-td>
        </template>

        <!-- Status Column -->
        <template #body-cell-status="props">
          <q-td :props="props" class="text-center">
            <q-badge
              :color="props.row.paid_amount > 0 ? 'amber-1' : 'grey-2'"
              :text-color="props.row.paid_amount > 0 ? 'amber-9' : 'grey-8'"
              class="text-uppercase text-weight-bold status-chip"
            >
              {{ props.row.paid_amount > 0 ? 'Partial' : 'Due' }}
            </q-badge>
          </q-td>
        </template>

        <!-- Actions Column -->
        <template #body-cell-actions="props">
          <q-td :props="props" class="text-right">
            <q-btn
              unelevated
              size="sm"
              color="primary"
              label="Pay"
              no-caps
              class="rounded-btn text-weight-medium"
              @click="goCollectInvoice(props.row)"
            />
          </q-td>
        </template>
      </q-table>
    </div>

    <CustomerPaymentHistoryDrawer
      v-if="historyGroup"
      v-model="historyOpen"
      :customer-group-id="historyGroup.id"
      :customer-name="historyGroup.name"
      :account-code="historyGroup.account_code"
      @void-and-reenter="onVoidAndReenter"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { type QTableProps } from 'quasar';
import { usePayments } from '../composables/usePaymentsQuery';
import type { CustomerGroupPaymentSummary, OpenInvoicePaymentItem } from '../types/paymentsTypes';
import CustomerPaymentHistoryDrawer from '../components/CustomerPaymentHistoryDrawer.vue';

const router = useRouter();
const {
  searchQuery,
  customerGroups,
  isCustomerGroupsLoading,
  openInvoices,
  isOpenInvoicesLoading,
  refetchAll,
} = usePayments();

const paymentMode = ref<'customer' | 'invoice'>('customer');
const invoiceStatusFilter = ref('all');
const historyOpen = ref(false);
const historyGroup = ref<CustomerGroupPaymentSummary | null>(null);

const viewTabs = [
  { label: 'Customer Groups', value: 'customer', icon: 'ph ph-users-three' },
  { label: 'Open Invoices', value: 'invoice', icon: 'ph ph-receipt' },
];

const statusOptions = [
  { label: 'All Open', value: 'all' },
  { label: 'Due Only', value: 'due' },
  { label: 'Partial Only', value: 'partial' },
];

const customerColumns: QTableProps['columns'] = [
  { name: 'customer', label: 'Customer Group / Account', field: 'name', align: 'left' },
  { name: 'branches', label: 'Outlets', field: 'branches', align: 'left' },
  { name: 'invoices', label: 'Open Invoices', field: 'open_invoice_count', align: 'center' },
  { name: 'total', label: 'Total Invoiced', field: 'total_invoiced', align: 'right' },
  { name: 'paid', label: 'Paid So Far', field: 'total_paid', align: 'right' },
  { name: 'due', label: 'Total Outstanding Due', field: 'total_due', align: 'right' },
  { name: 'actions', label: '', field: 'id', align: 'right' },
];

const invoiceColumns: QTableProps['columns'] = [
  { name: 'invoice_no', label: 'Invoice No', field: 'invoice_no', align: 'left' },
  { name: 'outlet', label: 'Customer / Outlet', field: 'customer_group_name', align: 'left' },
  { name: 'date', label: 'Issue Date', field: 'invoice_date', align: 'left' },
  { name: 'due_date', label: 'Due Date', field: 'due_date', align: 'left' },
  { name: 'total', label: 'Total', field: 'total_amount', align: 'right' },
  { name: 'paid', label: 'Paid', field: 'paid_amount', align: 'right' },
  { name: 'due', label: 'Due Balance', field: 'due_amount', align: 'right' },
  { name: 'status', label: 'Status', field: 'payment_status', align: 'center' },
  { name: 'actions', label: '', field: 'id', align: 'right' },
];

const filteredInvoices = computed(() => {
  let list = openInvoices.value;
  if (invoiceStatusFilter.value === 'due') {
    list = list.filter((i) => i.paid_amount === 0);
  } else if (invoiceStatusFilter.value === 'partial') {
    list = list.filter((i) => i.paid_amount > 0);
  }
  return list;
});

function getRowStatusClass(inv: OpenInvoicePaymentItem) {
  if (inv.paid_amount > 0) return 'row-tint-partial';
  return 'row-tint-due';
}

function isOverdue(dueDate: string | null) {
  if (!dueDate) return false;
  return new Date(dueDate) < new Date();
}

function openHistory(grp: CustomerGroupPaymentSummary) {
  historyGroup.value = grp;
  historyOpen.value = true;
}

function onVoidAndReenter(groupId: number) {
  historyOpen.value = false;
  refetchAll();
  void router.push({
    name: 'app-finance-payments-collect-page',
    params: { customerGroupId: String(groupId) },
  });
}

function goCollectGroup(grp: CustomerGroupPaymentSummary) {
  void router.push({
    name: 'app-finance-payments-collect-page',
    params: { customerGroupId: String(grp.id) },
  });
}

function goCollectInvoice(inv: OpenInvoicePaymentItem) {
  if (!inv.customer_group_id) return;
  void router.push({
    name: 'app-finance-payments-collect-page',
    params: { customerGroupId: String(inv.customer_group_id) },
    query: { invoiceId: String(inv.id) },
  });
}

function formatCurrency(val: number) {
  return Number(val || 0).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  overflow: hidden;
}

.rounded-btn {
  border-radius: 8px;
}

.status-chip {
  border-radius: 6px;
  font-size: 11px;
}

.text-2xs {
  font-size: 10px;
  line-height: 1.2;
}

.quick-filter-toggle {
  background: rgba(0, 0, 0, 0.04);
  border-radius: 8px;
  padding: 2px;
}

.quick-filter-btn {
  border-radius: 6px;
  font-size: 11px;
  font-weight: 600;
  padding: 4px 10px;
}

.dense-filter-select :deep(.q-field__control) {
  height: 32px;
  min-height: 32px;
  border-radius: 8px;
}

.dense-search-input :deep(.q-field__control) {
  height: 32px;
  min-height: 32px;
}

/* Row Status Accents */
.row-tint-partial {
  box-shadow: inset 3px 0 0 #f59e0b;
}

.row-tint-due {
  box-shadow: inset 3px 0 0 #9ca3af;
}

.treasury-ops-table {
  background: white;
}

.treasury-ops-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  font-weight: 700;
  font-size: 11px;
  background: var(--bw-neutral-canvas, #f8fafc);
  color: var(--bw-neutral-muted, #64748b);
  border-bottom: 1px solid var(--bw-neutral-border, #e2e8f0);
}

.treasury-ops-table :deep(.q-table__middle) {
  overflow-y: auto;
}

</style>
