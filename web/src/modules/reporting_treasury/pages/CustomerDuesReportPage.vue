<template>
  <FinanceReportFrame
    :loading="isLoading"
    :error="error"
    :export-disabled="!rows.length"
    @export="exportCsv"
    @refresh="() => refetch()"
  >
    <template #filters>
      <q-input
        v-model="searchText"
        outlined
        rounded
        dense
        clearable
        placeholder="Search customer..."
        class="dense-search-input bg-white"
        style="min-width: 200px"
      >
        <template #prepend>
          <q-icon name="ph ph-magnifying-glass" size="14px" />
        </template>
      </q-input>
      <q-chip
        v-for="bucket in agingOptions"
        :key="bucket.value ?? 'all'"
        clickable
        dense
        size="sm"
        :color="agingBucket === bucket.value ? 'primary' : 'grey-2'"
        :text-color="agingBucket === bucket.value ? 'white' : 'grey-9'"
        class="text-weight-bold"
        @click="agingBucket = bucket.value"
      >
        {{ bucket.label }}
      </q-chip>
      <q-toggle v-model="overLimitOnly" dense size="sm" label="Over limit" />
    </template>

    <template #kpi>
      <div class="row items-center q-gutter-x-md wrap q-gutter-y-xs">
        <KpiItem label="Still due" :value="totals?.still_due" highlight />
        <KpiItem label="Billed" :value="totals?.billed" />
        <KpiItem label="Returned" :value="totals?.returned" />
        <KpiItem label="Cash" :value="totals?.collected_cash" />
        <KpiItem label="Wallet" :value="totals?.wallet_applied" />
        <KpiItem label="Settlement" :value="totals?.settlement" />
        <KpiItem label="Customers" :value="totals?.customer_count" format="number" />
      </div>
    </template>

    <q-table
      flat
      dense
      :rows="rows"
      :columns="columns"
      row-key="billing_profile_id"
      :loading="isLoading"
      :pagination="{ rowsPerPage: 50 }"
      class="compact-ops-table full-height bg-white"
      no-data-label="No customers with outstanding dues"
      @row-click="(_, row) => openInvoices(row)"
    >
      <template #body-cell-still_due="props">
        <q-td :props="props" class="text-weight-bold text-negative bw-tabular">
          {{ formatAmountBdt(props.row.still_due) }}
        </q-td>
      </template>
      <template #body-cell-aging="props">
        <q-td :props="props" class="text-caption bw-tabular">
          {{ formatAging(props.row.aging) }}
        </q-td>
      </template>
    </q-table>
  </FinanceReportFrame>
</template>

<script setup lang="ts">
import { defineComponent, h } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import type { QTableColumn } from 'quasar';
import FinanceReportFrame from '../components/FinanceReportFrame.vue';
import { useCustomerDuesReport } from '../composables/useCustomerDuesReport';
import type { CustomerDuesAging, CustomerDuesRow } from '../types/financeReportTypes';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';

const router = useRouter();
const { tenantSlug } = storeToRefs(useAuthStore());
const {
  totals,
  rows,
  isLoading,
  error,
  searchText,
  agingBucket,
  overLimitOnly,
  exportCsv,
  refetch,
} = useCustomerDuesReport();

const agingOptions = [
  { label: 'All aging', value: null },
  { label: 'Current', value: 'current' },
  { label: '1-30', value: '1_30' },
  { label: '31-60', value: '31_60' },
  { label: '61-90', value: '61_90' },
  { label: '90+', value: '90_plus' },
];

const columns: QTableColumn<CustomerDuesRow>[] = [
  { name: 'name', label: 'Customer', field: 'name', align: 'left', sortable: true },
  { name: 'phone', label: 'Phone', field: 'phone', align: 'left' },
  { name: 'still_due', label: 'Still Due', field: 'still_due', align: 'right', sortable: true },
  { name: 'aging', label: 'Aging', field: 'aging', align: 'left' },
  { name: 'credit_limit', label: 'Credit Limit', field: 'credit_limit', align: 'right' },
  { name: 'open_invoice_count', label: 'Open Inv.', field: 'open_invoice_count', align: 'right' },
];

const KpiItem = defineComponent({
  props: {
    label: { type: String, required: true },
    value: { type: [Number, String], default: 0 },
    highlight: Boolean,
    format: { type: String, default: 'currency' },
  },
  setup(props) {
    return () =>
      h('div', { class: 'row items-baseline q-gutter-x-xs' }, [
        h('span', { class: 'text-caption text-grey-7 text-uppercase font-bold', style: 'font-size:11px' }, props.label),
        h(
          'span',
          {
            class: `text-subtitle2 text-weight-bolder bw-tabular ${props.highlight ? 'text-negative' : 'text-primary'}`,
          },
          props.format === 'number' ? String(props.value ?? 0) : formatAmountBdt(Number(props.value || 0)),
        ),
      ]);
  },
});

function formatAging(aging: CustomerDuesAging) {
  const parts = [
    aging.current ? `Cur ${formatAmountBdt(aging.current)}` : '',
    aging.d1_30 ? `1-30 ${formatAmountBdt(aging.d1_30)}` : '',
    aging.d31_60 ? `31-60 ${formatAmountBdt(aging.d31_60)}` : '',
    aging.d61_90 ? `61-90 ${formatAmountBdt(aging.d61_90)}` : '',
    aging.d90_plus ? `90+ ${formatAmountBdt(aging.d90_plus)}` : '',
  ].filter(Boolean);
  return parts.join(' · ') || '—';
}

function openInvoices(row: CustomerDuesRow) {
  void router.push({
    path: `/${tenantSlug.value || 'tenant'}/app/sales/invoices`,
    query: {
      billing_profile_id: String(row.billing_profile_id),
      invoice_status: 'issued',
      quick_filter: 'unpaid',
    },
  });
}
</script>

<style scoped>
.dense-search-input :deep(.q-field__control) {
  height: 30px;
  min-height: 30px;
}
</style>
