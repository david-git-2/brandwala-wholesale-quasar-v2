<template>
  <FinanceReportFrame
    :loading="isLoading"
    :error="error"
    :export-disabled="!rows.length"
    @export="exportCsv"
    @refresh="() => refetch()"
  >
    <template #filters>
      <DatePresetPills :preset="preset" @set="setPreset" />
      <template v-if="preset === 'custom'">
        <q-input v-model="startDate" dense outlined type="date" class="compact-date-input bg-white" />
        <span class="text-caption text-grey-6">to</span>
        <q-input v-model="endDate" dense outlined type="date" class="compact-date-input bg-white" />
      </template>
      <q-chip
        v-for="opt in typeOptions"
        :key="opt.value ?? 'all-type'"
        clickable dense size="sm"
        :color="invoiceType === opt.value ? 'primary' : 'grey-2'"
        :text-color="invoiceType === opt.value ? 'white' : 'grey-9'"
        @click="invoiceType = opt.value"
      >{{ opt.label }}</q-chip>
      <q-input
        v-model="searchText"
        outlined rounded dense clearable
        placeholder="Search invoice or customer..."
        class="dense-search-input bg-white"
        style="min-width: 200px"
      >
        <template #prepend><q-icon name="ph ph-magnifying-glass" size="14px" /></template>
      </q-input>
    </template>

    <template #kpi>
      <div class="row items-center q-gutter-x-md wrap q-gutter-y-xs">
        <Kpi label="Billed" :value="totals?.billed" />
        <Kpi label="Returned" :value="totals?.returned" />
        <Kpi label="Cash" :value="totals?.collected_cash" />
        <Kpi label="Wallet" :value="totals?.wallet_applied" />
        <Kpi label="Settlement" :value="totals?.settlement" />
        <Kpi label="Still due" :value="totals?.still_due" highlight />
        <Kpi label="Invoices" :value="totals?.invoice_count" number />
      </div>
    </template>

    <q-table
      flat dense :rows="rows" :columns="columns" row-key="id"
      :loading="isLoading" :pagination="{ rowsPerPage: 50 }"
      class="compact-ops-table full-height bg-white"
      @row-click="(_, row) => openInvoice(row)"
    />
  </FinanceReportFrame>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import type { QTableColumn } from 'quasar';
import FinanceReportFrame from '../components/FinanceReportFrame.vue';
import DatePresetPills from '../components/DatePresetPills.vue';
import ReportKpiStrip from '../components/ReportKpiStrip.vue';
import { useInvoiceBookReport } from '../composables/useInvoiceBookReport';
import type { InvoiceBookRow } from '../types/financeReportTypes';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';

const Kpi = ReportKpiStrip;
const router = useRouter();
const { tenantSlug } = storeToRefs(useAuthStore());
const {
  totals, rows, isLoading, error, preset, startDate, endDate, searchText, invoiceType, setPreset, exportCsv, refetch,
} = useInvoiceBookReport();

const typeOptions = [
  { label: 'All types', value: null },
  { label: 'Wholesale', value: 'wholesale' },
  { label: 'Retail', value: 'retail' },
  { label: 'Dropship', value: 'dropship' },
];

const columns: QTableColumn<InvoiceBookRow>[] = [
  { name: 'invoice_no', label: 'Invoice', field: 'invoice_no', align: 'left', sortable: true },
  { name: 'invoice_date', label: 'Date', field: 'invoice_date', align: 'left', sortable: true },
  { name: 'customer_name', label: 'Customer', field: 'customer_name', align: 'left' },
  { name: 'invoice_type', label: 'Type', field: 'invoice_type', align: 'left' },
  { name: 'payment_status', label: 'Payment', field: 'payment_status', align: 'left' },
  { name: 'billed', label: 'Billed', field: 'billed', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
  { name: 'returned', label: 'Returned', field: 'returned', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
  { name: 'collected_cash', label: 'Cash', field: 'collected_cash', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
  { name: 'still_due', label: 'Due', field: 'still_due', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
];

function openInvoice(row: InvoiceBookRow) {
  void router.push({
    name: 'app-global-invoice-details-page',
    params: { tenantSlug: tenantSlug.value || 'tenant', id: row.id },
  });
}
</script>

<style scoped>
.compact-date-input { width: 130px; }
.dense-search-input :deep(.q-field__control) { height: 30px; min-height: 30px; }
</style>
