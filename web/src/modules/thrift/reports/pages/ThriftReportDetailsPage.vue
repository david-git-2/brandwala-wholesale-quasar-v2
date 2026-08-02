<template>
  <q-page class="q-pa-md thrift-report-details-page">
    <div class="q-gutter-y-md">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-auto row items-center q-gutter-x-sm">
          <q-btn flat round dense icon="ph ph-arrow-left" color="primary" :to="reportsListPath">
            <q-tooltip>Back to Reports</q-tooltip>
          </q-btn>
          <div>
            <div class="text-overline text-primary">Thrift / Reports</div>
            <h1 class="text-h5 text-weight-bold q-my-none">
              {{ report?.shipment.name || 'Shipment Sales Report' }}
            </h1>
          </div>
        </div>
      </div>

      <div v-if="isLoading" class="column flex-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
      </div>

      <div v-else-if="isError" class="bg-negative text-white q-pa-md rounded-borders">
        {{ errorMessage }}
      </div>

      <template v-else-if="report">
        <div class="row q-col-gutter-md">
          <div class="col-6 col-sm-4 col-md">
            <q-card flat bordered class="stat-card">
              <q-card-section>
                <div class="text-caption text-grey-6">Units sold</div>
                <div class="text-h6 text-weight-bold">{{ summary.unitsSold }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6 col-sm-4 col-md">
            <q-card flat bordered class="stat-card">
              <q-card-section>
                <div class="text-caption text-grey-6">Net revenue</div>
                <div class="text-h6 text-weight-bold text-primary">
                  {{ formatThriftAmount(summary.netRevenue) }}
                </div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6 col-sm-4 col-md">
            <q-card flat bordered class="stat-card">
              <q-card-section>
                <div class="text-caption text-grey-6">COGS</div>
                <div class="text-h6 text-weight-bold">
                  {{ formatThriftAmount(summary.cogs) }}
                </div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6 col-sm-4 col-md">
            <q-card flat bordered class="stat-card">
              <q-card-section>
                <div class="text-caption text-grey-6">Net profit</div>
                <div
                  class="text-h6 text-weight-bold"
                  :class="summary.netProfit >= 0 ? 'text-positive' : 'text-negative'"
                >
                  {{ formatThriftAmount(summary.netProfit) }}
                </div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6 col-sm-4 col-md">
            <q-card flat bordered class="stat-card">
              <q-card-section>
                <div class="text-caption text-grey-6">Margin</div>
                <div
                  class="text-h6 text-weight-bold"
                  :class="summary.marginPct >= 0 ? 'text-positive' : 'text-negative'"
                >
                  {{ summary.marginPct.toFixed(1) }}%
                </div>
              </q-card-section>
            </q-card>
          </div>
        </div>

        <q-card flat bordered>
          <q-card-section class="q-pb-none">
            <div class="row items-center justify-between q-col-gutter-sm">
              <div class="text-subtitle1 text-weight-bold">
                Sold line items ({{ report.lines.length }})
              </div>
              <div class="text-caption text-grey-7">
                Gross {{ formatThriftAmount(summary.grossSales) }}
                · Discounts {{ formatThriftAmount(summary.discounts) }}
              </div>
            </div>
          </q-card-section>

          <q-card-section class="q-pb-none" v-if="report.lines.length">
            <q-input
              v-model="lineSearch"
              dense
              outlined
              clearable
              debounce="200"
              placeholder="Search invoice #, item, barcode…"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
          </q-card-section>

          <q-table
            flat
            :rows="filteredLines"
            :columns="lineColumns"
            row-key="id"
            :pagination="{ rowsPerPage: 25 }"
            :rows-per-page-options="[25, 50, 100]"
            class="thrift-table"
          >
            <template #body-cell-invoice="props">
              <q-td :props="props">
                <div class="text-weight-medium">{{ props.row.invoiceNumber }}</div>
                <div class="text-caption text-grey-7">{{ formatDate(props.row.invoiceDate) }}</div>
              </q-td>
            </template>

            <template #body-cell-item="props">
              <q-td :props="props">
                <div class="text-weight-medium">
                  {{ props.row.stockName || `Stock #${props.row.stockId}` }}
                </div>
                <div v-if="props.row.barcode" class="text-caption text-grey-7">
                  {{ props.row.barcode }}
                </div>
              </q-td>
            </template>

            <template #body-cell-sellPrice="props">
              <q-td :props="props" class="text-right">
                {{ formatThriftAmount(props.row.sellPrice) }}
              </q-td>
            </template>

            <template #body-cell-discountAmount="props">
              <q-td :props="props" class="text-right">
                {{ formatThriftAmount(props.row.discountAmount) }}
              </q-td>
            </template>

            <template #body-cell-finalPrice="props">
              <q-td :props="props" class="text-right text-weight-medium">
                {{ formatThriftAmount(props.row.finalPrice) }}
              </q-td>
            </template>

            <template #body-cell-landedUnitCostAtSale="props">
              <q-td :props="props" class="text-right">
                {{ formatThriftAmount(props.row.landedUnitCostAtSale) }}
              </q-td>
            </template>

            <template #body-cell-netProfit="props">
              <q-td
                :props="props"
                class="text-right text-weight-bold"
                :class="props.row.netProfit >= 0 ? 'text-positive' : 'text-negative'"
              >
                {{ formatThriftAmount(props.row.netProfit) }}
              </q-td>
            </template>

            <template #no-data>
              <div class="full-width column flex-center q-pa-xl text-grey-6">
                <q-icon name="ph ph-receipt" size="40px" class="q-mb-sm" />
                <div class="text-subtitle1 text-weight-medium">No sales yet</div>
                <div class="text-body2">
                  Active invoice lines for this shipment will appear here.
                </div>
              </div>
            </template>
          </q-table>
        </q-card>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import { storeToRefs } from 'pinia';
import type { QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import { useThriftShipmentSalesReportQuery } from '../composables/useThriftReportsQuery';

const route = useRoute();
const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);

const lineSearch = ref('');

const shipmentId = computed(() => {
  const raw = route.params.shipmentId;
  const n = Number(Array.isArray(raw) ? raw[0] : raw);
  return Number.isFinite(n) && n > 0 ? n : null;
});

const reportsListPath = computed(
  () => `/${tenantSlug.value || 'tenant'}/app/thrift/reports`,
);

const { data: report, isLoading, isError, error } = useThriftShipmentSalesReportQuery(
  tenantId,
  shipmentId,
);

const summary = computed(
  () =>
    report.value?.summary || {
      unitsSold: 0,
      grossSales: 0,
      discounts: 0,
      netRevenue: 0,
      cogs: 0,
      netProfit: 0,
      marginPct: 0,
    },
);

const errorMessage = computed(() => {
  if (!error.value) return 'Failed to load report';
  return error.value instanceof Error ? error.value.message : String(error.value);
});

const lineColumns: QTableColumn[] = [
  { name: 'invoice', label: 'Invoice', field: 'invoiceNumber', align: 'left' },
  { name: 'item', label: 'Item', field: 'stockName', align: 'left' },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'right', style: 'width: 64px' },
  { name: 'sellPrice', label: 'Sell', field: 'sellPrice', align: 'right' },
  { name: 'discountAmount', label: 'Discount', field: 'discountAmount', align: 'right' },
  { name: 'finalPrice', label: 'Final', field: 'finalPrice', align: 'right' },
  {
    name: 'landedUnitCostAtSale',
    label: 'Landed cost',
    field: 'landedUnitCostAtSale',
    align: 'right',
  },
  { name: 'netProfit', label: 'Profit', field: 'netProfit', align: 'right' },
];

const filteredLines = computed(() => {
  const lines = report.value?.lines || [];
  const q = lineSearch.value.trim().toLowerCase();
  if (!q) return lines;
  return lines.filter(
    (line) =>
      line.invoiceNumber.toLowerCase().includes(q) ||
      (line.stockName || '').toLowerCase().includes(q) ||
      (line.barcode || '').toLowerCase().includes(q) ||
      String(line.stockId).includes(q),
  );
});

function formatDate(value: string) {
  if (!value) return '—';
  try {
    return new Date(value).toLocaleString();
  } catch {
    return value;
  }
}
</script>
