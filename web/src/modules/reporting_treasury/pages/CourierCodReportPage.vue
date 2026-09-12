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
    </template>

    <template #kpi>
      <div class="row items-center q-gutter-x-md wrap q-gutter-y-xs">
        <ReportKpiStrip label="Delivered COD" :value="totals?.delivered_cod" />
        <ReportKpiStrip label="Remitted" :value="totals?.remitted" />
        <ReportKpiStrip label="Unremitted" :value="totals?.unremitted" highlight />
        <ReportKpiStrip label="Short / over" :value="totals?.short_over" />
        <ReportKpiStrip label="Orders" :value="totals?.order_count" number />
      </div>
    </template>

    <q-table
      flat dense :rows="rows" :columns="columns" row-key="courier_name"
      :loading="isLoading" :pagination="{ rowsPerPage: 50 }"
      class="compact-ops-table full-height bg-white"
      no-data-label="No delivered dropship COD in this period"
      @row-click="(_, row) => openCourier(row)"
    />
  </FinanceReportFrame>

  <q-dialog v-model="ordersOpen">
    <q-card style="min-width: 760px; max-width: 95vw">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6">{{ selectedCourierName }} orders</div>
        <q-space />
        <q-btn flat round dense icon="ph ph-x" @click="ordersOpen = false" />
      </q-card-section>
      <q-card-section>
        <q-table
          flat dense :rows="orders" :columns="orderColumns" row-key="order_id"
          :loading="ordersLoading" hide-pagination :pagination="{ rowsPerPage: 0 }"
        />
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import type { QTableColumn } from 'quasar';
import FinanceReportFrame from '../components/FinanceReportFrame.vue';
import DatePresetPills from '../components/DatePresetPills.vue';
import ReportKpiStrip from '../components/ReportKpiStrip.vue';
import { useCourierCodReport } from '../composables/useCourierCodReport';
import type { CourierCodOrderRow, CourierCodRow } from '../types/financeReportTypes';
import { formatAmountBdt } from 'src/utils/currency';

const {
  totals, rows, orders, ordersLoading, isLoading, error,
  preset, startDate, endDate, selectedCourierId, setPreset, exportCsv, refetch,
} = useCourierCodReport();

const ordersOpen = ref(false);
const selectedCourierName = ref('Courier');

watch(selectedCourierId, (id) => {
  ordersOpen.value = Boolean(id);
});

const columns: QTableColumn<CourierCodRow>[] = [
  { name: 'courier_name', label: 'Courier', field: 'courier_name', align: 'left', sortable: true },
  { name: 'delivered_cod', label: 'Delivered COD', field: 'delivered_cod', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
  { name: 'remitted', label: 'Remitted', field: 'remitted', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
  { name: 'unremitted', label: 'Unremitted', field: 'unremitted', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
  { name: 'short_over', label: 'Short/Over', field: 'short_over', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
  { name: 'order_count', label: 'Orders', field: 'order_count', align: 'right' },
];

const orderColumns: QTableColumn<CourierCodOrderRow>[] = [
  { name: 'order_no', label: 'Order', field: 'order_no', align: 'left' },
  { name: 'awb', label: 'AWB', field: 'awb', align: 'left' },
  { name: 'cod_collect_amount', label: 'COD', field: 'cod_collect_amount', align: 'right', format: (v) => formatAmountBdt(Number(v)) },
  { name: 'remittance_ref', label: 'Remittance', field: 'remittance_ref', align: 'left' },
  { name: 'delivered_at', label: 'Delivered', field: 'delivered_at', align: 'left' },
];

function openCourier(row: CourierCodRow) {
  selectedCourierName.value = row.courier_name;
  selectedCourierId.value = row.courier_service_id;
  ordersOpen.value = true;
}
</script>

<style scoped>
.compact-date-input { width: 130px; }
</style>
