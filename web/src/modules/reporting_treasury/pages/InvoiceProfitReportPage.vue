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
        <ReportKpiStrip label="Revenue" :value="totals?.net_revenue" />
        <ReportKpiStrip label="COGS" :value="totals?.cogs" />
        <ReportKpiStrip label="Gross profit" :value="totals?.realized_gp" highlight />
        <div class="row items-baseline q-gutter-x-xs">
          <span class="text-caption text-grey-7 text-uppercase font-bold" style="font-size:11px">Margin:</span>
          <span class="text-subtitle2 text-weight-bolder bw-tabular text-primary">
            {{ Number(totals?.gp_margin_pct ?? 0).toFixed(1) }}%
          </span>
        </div>
        <ReportKpiStrip label="Invoices" :value="totals?.invoice_count" number />
      </div>
    </template>

    <q-table
      flat dense :rows="rows" :columns="columns" row-key="id"
      :loading="isLoading" :pagination="{ rowsPerPage: 50 }"
      class="compact-ops-table full-height bg-white"
      @row-click="(_, row) => openDetail(row)"
    />
  </FinanceReportFrame>

  <InvoiceProfitDetailDialog
    v-model="detailOpen"
    :title="detailTitle"
    :lines="detailLines"
    :loading="detailLoading"
  />
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import type { QTableColumn } from 'quasar';
import FinanceReportFrame from '../components/FinanceReportFrame.vue';
import DatePresetPills from '../components/DatePresetPills.vue';
import ReportKpiStrip from '../components/ReportKpiStrip.vue';
import InvoiceProfitDetailDialog from '../components/InvoiceProfitDetailDialog.vue';
import { useInvoiceProfitReport } from '../composables/useInvoiceProfitReport';
import type { InvoiceProfitRow } from '../types/financeReportTypes';
import { formatAmountBdt } from 'src/utils/currency';

const {
  totals, rows, detailLines, detailLoading, isLoading, error,
  preset, startDate, endDate, searchText, selectedInvoiceId, setPreset, exportCsv, refetch,
} = useInvoiceProfitReport();

const detailOpen = ref(false);
const detailTitle = ref('Invoice lines');

watch(selectedInvoiceId, (id) => {
  detailOpen.value = Boolean(id);
});

const columns: QTableColumn<InvoiceProfitRow>[] = [
  { name: 'invoice_no', label: 'Invoice', field: 'invoice_no', align: 'left', sortable: true },
  { name: 'invoice_date', label: 'Date', field: 'invoice_date', align: 'left' },
  { name: 'customer_name', label: 'Customer', field: 'customer_name', align: 'left' },
  { name: 'net_revenue', label: 'Revenue', field: 'net_revenue', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
  { name: 'cogs', label: 'COGS', field: 'cogs', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
  { name: 'realized_gp', label: 'GP', field: 'realized_gp', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
  { name: 'gp_margin_pct', label: 'Margin %', field: 'gp_margin_pct', align: 'right', format: (v) => `${Number(v).toFixed(1)}%` },
];

function openDetail(row: InvoiceProfitRow) {
  detailTitle.value = `${row.invoice_no} — line profit`;
  selectedInvoiceId.value = row.id;
  detailOpen.value = true;
}
</script>

<style scoped>
.compact-date-input { width: 130px; }
.dense-search-input :deep(.q-field__control) { height: 30px; min-height: 30px; }
</style>
