<template>
  <FinanceReportFrame
    :loading="isLoading"
    :error="error ? (error as Error).message : null"
    :show-export="false"
    @refresh="() => refetch()"
  >
    <template #filters>
      <q-btn flat dense no-caps color="primary" icon="ph ph-arrow-left" label="Back" :to="listRoute" />
      <span v-if="header?.group_name" class="text-subtitle2 text-weight-bold q-ml-sm ellipsis">
        {{ header.group_name }}
      </span>
    </template>

    <template #kpi>
      <div v-if="header" class="row items-center q-gutter-md wrap">
        <ReportKpiStrip label="Still due" :value="header.still_due" highlight />
        <ReportKpiStrip label="Store credit" :value="header.store_credit_balance" />
        <ReportKpiStrip label="Unallocated pay" :value="header.unallocated_payments" />
        <ReportKpiStrip label="Billed" :value="header.total_billed" />
        <ReportKpiStrip label="Cash applied" :value="header.collected_cash" />
        <ReportKpiStrip label="Write-off" :value="header.settlement" />
      </div>
    </template>

    <div v-if="header" class="detail-scroll">
      <div class="detail-inner column q-gutter-md">
        <ShipmentReportSectionShell title="Customer">
          <div class="column q-gutter-y-xs text-body2">
            <div v-if="header.phone">
              <span class="text-grey-7">Phone</span>
              <span class="q-ml-sm">{{ header.phone }}</span>
            </div>
            <div v-if="header.email">
              <span class="text-grey-7">Email</span>
              <span class="q-ml-sm">{{ header.email }}</span>
            </div>
            <div v-if="header.address">
              <span class="text-grey-7">Address</span>
              <span class="q-ml-sm">{{ header.address }}</span>
            </div>
            <div class="text-caption text-grey-7">
              Group #{{ header.customer_group_id }}
              <span v-if="header.profile_id"> · Profile #{{ header.profile_id }}</span>
            </div>
          </div>
        </ShipmentReportSectionShell>

        <CustomerReportSection
          v-if="header.members?.length"
          title="Members"
          :rows="header.members"
          :columns="memberColumns"
          row-key="id"
          :is-loading="false"
          :has-more="false"
          :is-loading-more="false"
          :fetch-next-page="noop"
        />

        <CustomerReportSection
          title="Payments & deposits"
          :rows="payments.rows"
          :columns="paymentColumns"
          row-key="payment_id"
          :is-loading="payments.isLoading"
          :has-more="payments.hasMore"
          :is-loading-more="payments.isLoadingMore"
          :fetch-next-page="() => payments.fetchNextPage()"
        />

        <CustomerReportSection
          title="Orders"
          :rows="orders.rows"
          :columns="orderColumns"
          row-key="order_id"
          :is-loading="orders.isLoading"
          :has-more="orders.hasMore"
          :is-loading-more="orders.isLoadingMore"
          :fetch-next-page="() => orders.fetchNextPage()"
        >
          <template #body-cell-status="props">
            <q-td :props="props">
              <TfStatusBadge :status="props.row.status" :label="props.row.status" />
            </q-td>
          </template>
        </CustomerReportSection>

        <CustomerReportSection
          title="Bills"
          :rows="bills.rows"
          :columns="billColumns"
          row-key="bill_id"
          :is-loading="bills.isLoading"
          :has-more="bills.hasMore"
          :is-loading-more="bills.isLoadingMore"
          :fetch-next-page="() => bills.fetchNextPage()"
        />

        <CustomerReportSection
          title="Wallet ledger"
          :rows="ledger.rows"
          :columns="ledgerColumns"
          row-key="entry_id"
          :is-loading="ledger.isLoading"
          :has-more="ledger.hasMore"
          :is-loading-more="ledger.isLoadingMore"
          :fetch-next-page="() => ledger.fetchNextPage()"
        />
      </div>
    </div>
  </FinanceReportFrame>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { storeToRefs } from 'pinia';
import type { QTableColumn } from 'quasar';
import FinanceReportFrame from '../components/FinanceReportFrame.vue';
import CustomerReportSection from '../components/customerReport/CustomerReportSection.vue';
import ShipmentReportSectionShell from '../components/shipmentReport/ShipmentReportSectionShell.vue';
import ReportKpiStrip from '../components/ReportKpiStrip.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import {
  useCustomerReportHeader,
  useCustomerReportSection,
} from '../composables/useCustomerReportDetail';
import type {
  CustomerReportBillRow,
  CustomerReportLedgerRow,
  CustomerReportMember,
  CustomerReportOrderRow,
  CustomerReportPaymentRow,
} from '../types/customersReportTypes';

const route = useRoute();
const authStore = useAuthStore();
const { tenantSlug } = storeToRefs(authStore);

const customerGroupId = computed(() => {
  const raw = route.params.customerGroupId;
  const n = typeof raw === 'string' ? Number.parseInt(raw, 10) : NaN;
  return Number.isFinite(n) && n > 0 ? n : null;
});

const listRoute = computed(() => ({
  name: 'app-finance-customers-report-page',
  params: { tenantSlug: tenantSlug.value || undefined },
}));

const { header, isLoading, error, refetch } = useCustomerReportHeader(customerGroupId);
const payments = useCustomerReportSection(customerGroupId, 'payments');
const orders = useCustomerReportSection(customerGroupId, 'orders');
const bills = useCustomerReportSection(customerGroupId, 'bills');
const ledger = useCustomerReportSection(customerGroupId, 'ledger');

const noop = () => undefined;

const memberColumns: QTableColumn<CustomerReportMember>[] = [
  { name: 'name', label: 'Name', field: 'name', align: 'left' },
  { name: 'email', label: 'Email', field: 'email', align: 'left' },
  { name: 'role', label: 'Role', field: 'role', align: 'left' },
];

const paymentColumns: QTableColumn<CustomerReportPaymentRow>[] = [
  { name: 'date', label: 'Date', field: 'payment_date', align: 'left' },
  { name: 'method', label: 'Method', field: 'method', align: 'left' },
  {
    name: 'amount',
    label: 'Amount',
    field: 'amount',
    align: 'right',
    classes: 'tf-tabular',
    format: (v) => formatAmountBdt(v as number),
  },
  {
    name: 'unallocated',
    label: 'Unallocated',
    field: 'unallocated_amount',
    align: 'right',
    classes: 'tf-tabular',
    format: (v) => formatAmountBdt(v as number),
  },
  { name: 'source', label: 'Source', field: 'source', align: 'left' },
];

const orderColumns: QTableColumn<CustomerReportOrderRow>[] = [
  { name: 'order_no', label: 'Order', field: 'order_no', align: 'left' },
  { name: 'status', label: 'Status', field: 'status', align: 'left' },
  { name: 'shop', label: 'Shop', field: 'shop_name', align: 'left' },
  {
    name: 'cod',
    label: 'COD',
    field: 'cod_collect_amount',
    align: 'right',
    classes: 'tf-tabular',
    format: (v) => (v == null ? '—' : formatAmountBdt(v as number)),
  },
  { name: 'recipient', label: 'Recipient', field: 'recipient_name', align: 'left' },
];

const billColumns: QTableColumn<CustomerReportBillRow>[] = [
  { name: 'invoice_no', label: 'Invoice', field: 'invoice_no', align: 'left' },
  { name: 'payment_status', label: 'Pay status', field: 'payment_status', align: 'left' },
  {
    name: 'total',
    label: 'Total',
    field: 'total_amount',
    align: 'right',
    classes: 'tf-tabular',
    format: (v) => formatAmountBdt(v as number),
  },
  {
    name: 'due',
    label: 'Due',
    field: 'due_amount',
    align: 'right',
    classes: 'tf-tabular',
    format: (v) => formatAmountBdt(v as number),
  },
];

const ledgerColumns: QTableColumn<CustomerReportLedgerRow>[] = [
  {
    name: 'date',
    label: 'Date',
    field: 'created_at',
    align: 'left',
    format: (v) => String(v).slice(0, 10),
  },
  { name: 'type', label: 'Type', field: 'type', align: 'left' },
  { name: 'label', label: 'Label', field: 'label', align: 'left' },
  {
    name: 'amount',
    label: 'Amount',
    field: 'amount',
    align: 'right',
    classes: 'tf-tabular',
    format: (v) => formatAmountBdt(v as number),
  },
];
</script>

<style scoped>
.detail-scroll {
  overflow-y: auto;
  max-height: 100%;
  min-height: 0;
  flex: 1 1 auto;
}

.detail-inner {
  max-width: 1200px;
  margin: 0 auto;
  padding: 8px;
  width: 100%;
}

.detail-scroll :deep(.customer-report-table .q-table__container) {
  height: auto;
  max-height: none;
}

.detail-scroll :deep(.customer-report-table .q-table__middle) {
  flex: none;
  overflow-y: visible;
}
</style>