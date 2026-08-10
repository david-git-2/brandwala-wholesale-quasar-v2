<template>
  <q-page class="q-pa-md thrift-sales-report-page">
    <div class="q-gutter-y-md">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-auto row items-center q-gutter-x-sm">
          <q-btn flat round dense icon="ph ph-arrow-left" color="primary" :to="reportsListPath">
            <q-tooltip>Back to Reports</q-tooltip>
          </q-btn>
          <div>
            <div class="text-overline text-primary">Thrift / Reports</div>
            <h1 class="text-h5 text-weight-bold q-my-none">Sales Report</h1>
          </div>
        </div>
      </div>

      <q-card flat bordered>
        <q-card-section class="row q-col-gutter-md items-end">
          <div class="col-12 col-sm-3">
            <q-input v-model="dateFrom" type="date" label="From" outlined dense />
          </div>
          <div class="col-12 col-sm-3">
            <q-input v-model="dateTo" type="date" label="To" outlined dense />
          </div>
          <div class="col-12 col-sm-4">
            <q-select
              v-model="saleChannel"
              :options="channelOptions"
              label="Channel"
              outlined
              dense
              emit-value
              map-options
            />
          </div>
          <div class="col-12 col-sm-2">
            <q-btn
              color="primary"
              unelevated
              no-caps
              class="full-width"
              icon="ph ph-arrows-clockwise"
              label="Refresh"
              :loading="isFetching"
              @click="() => refetch()"
            />
          </div>
        </q-card-section>
      </q-card>

      <div v-if="isLoading" class="column flex-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
      </div>

      <div v-else-if="isError" class="bg-negative text-white q-pa-md rounded-borders">
        {{ errorMessage }}
      </div>

      <template v-else-if="report">
        <div class="row q-col-gutter-md">
          <div class="col-6 col-sm-4 col-md-3">
            <q-card flat bordered class="stat-card">
              <q-card-section>
                <div class="text-caption text-grey-6">Invoices</div>
                <div class="text-h6 text-weight-bold">{{ summary.invoiceCount }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6 col-sm-4 col-md-3">
            <q-card flat bordered class="stat-card">
              <q-card-section>
                <div class="text-caption text-grey-6">Units sold</div>
                <div class="text-h6 text-weight-bold">{{ summary.unitsSold }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6 col-sm-4 col-md-3">
            <q-card flat bordered class="stat-card">
              <q-card-section>
                <div class="text-caption text-grey-6">Net revenue</div>
                <div class="text-h6 text-weight-bold text-primary">
                  {{ formatThriftAmount(summary.netRevenue) }}
                </div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6 col-sm-4 col-md-3">
            <q-card flat bordered class="stat-card">
              <q-card-section>
                <div class="text-caption text-grey-6">COGS (live)</div>
                <div class="text-h6 text-weight-bold">
                  {{ formatThriftAmount(summary.cogs) }}
                </div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6 col-sm-4 col-md-3">
            <q-card flat bordered class="stat-card">
              <q-card-section>
                <div class="text-caption text-grey-6">Line profit</div>
                <div
                  class="text-h6 text-weight-bold"
                  :class="summary.lineProfit >= 0 ? 'text-positive' : 'text-negative'"
                >
                  {{ formatThriftAmount(summary.lineProfit) }}
                </div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6 col-sm-4 col-md-3">
            <q-card flat bordered class="stat-card">
              <q-card-section>
                <div class="text-caption text-grey-6">Shop courier fees</div>
                <div class="text-h6 text-weight-bold">
                  {{ formatThriftAmount(summary.totalFees) }}
                </div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6 col-sm-4 col-md-3">
            <q-card flat bordered class="stat-card">
              <q-card-section>
                <div class="text-caption text-grey-6">Net after fees</div>
                <div
                  class="text-h6 text-weight-bold"
                  :class="summary.netAfterFees >= 0 ? 'text-positive' : 'text-negative'"
                >
                  {{ formatThriftAmount(summary.netAfterFees) }}
                </div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6 col-sm-4 col-md-3">
            <q-card flat bordered class="stat-card">
              <q-card-section>
                <div class="text-caption text-grey-6">Refunds</div>
                <div class="text-h6 text-weight-bold text-warning">
                  {{ summary.refundCount }}
                  <span class="text-caption text-weight-medium">
                    · {{ formatThriftAmount(summary.refundAmount) }}
                  </span>
                </div>
              </q-card-section>
            </q-card>
          </div>
        </div>

        <q-card flat bordered>
          <q-card-section class="row q-col-gutter-md">
            <div class="col-12">
              <div class="text-subtitle2 text-weight-bold">COD outstanding</div>
              <div class="text-caption text-grey-6">
                All open COD_PENDING invoices (not filtered by date range)
              </div>
            </div>
            <div class="col-4">
              <div class="text-caption text-grey-6">Invoices</div>
              <div class="text-h6 text-weight-bold">{{ codOutstanding.invoiceCount }}</div>
            </div>
            <div class="col-4">
              <div class="text-caption text-grey-6">Expected</div>
              <div class="text-h6 text-weight-bold text-warning">
                {{ formatThriftAmount(codOutstanding.codExpectedTotal) }}
              </div>
            </div>
            <div class="col-4">
              <div class="text-caption text-grey-6">Remitted</div>
              <div class="text-h6 text-weight-bold">
                {{ formatThriftAmount(codOutstanding.codRemittedTotal) }}
              </div>
            </div>
          </q-card-section>
        </q-card>

        <q-card flat bordered>
          <q-card-section class="q-pb-none">
            <div class="text-subtitle1 text-weight-bold">By channel</div>
          </q-card-section>
          <q-table
            flat
            :rows="report.byChannel"
            :columns="channelColumns"
            row-key="saleChannel"
            hide-pagination
            :rows-per-page-options="[0]"
            class="thrift-table"
          >
            <template #body-cell-saleChannel="props">
              <q-td :props="props">
                {{ props.row.saleChannel === 'ONLINE' ? 'Online' : 'In-store' }}
              </q-td>
            </template>
            <template #body-cell-netRevenue="props">
              <q-td :props="props" class="text-right">
                {{ formatThriftAmount(props.row.netRevenue) }}
              </q-td>
            </template>
            <template #body-cell-cogs="props">
              <q-td :props="props" class="text-right">
                {{ formatThriftAmount(props.row.cogs) }}
              </q-td>
            </template>
            <template #body-cell-lineProfit="props">
              <q-td :props="props" class="text-right">
                {{ formatThriftAmount(props.row.lineProfit) }}
              </q-td>
            </template>
            <template #body-cell-totalFees="props">
              <q-td :props="props" class="text-right">
                {{ formatThriftAmount(props.row.totalFees) }}
              </q-td>
            </template>
            <template #body-cell-netAfterFees="props">
              <q-td :props="props" class="text-right text-weight-bold">
                {{ formatThriftAmount(props.row.netAfterFees) }}
              </q-td>
            </template>
            <template #no-data>
              <div class="full-width column flex-center q-pa-lg text-grey-6">
                No ACTIVE sales in this range.
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
import { storeToRefs } from 'pinia';
import type { QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import { useThriftPeriodSalesReportQuery } from '../composables/useThriftReportsQuery';

function startOfMonthIsoDate(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`;
}

function todayIsoDate(): string {
  return new Date().toISOString().slice(0, 10);
}

function dayStartIso(date: string): string {
  return new Date(`${date}T00:00:00`).toISOString();
}

function dayEndIso(date: string): string {
  return new Date(`${date}T23:59:59.999`).toISOString();
}

const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);

const dateFrom = ref(startOfMonthIsoDate());
const dateTo = ref(todayIsoDate());
const saleChannel = ref<'IN_STORE' | 'ONLINE' | null>(null);

const dateFromIso = computed(() => dayStartIso(dateFrom.value));
const dateToIso = computed(() => dayEndIso(dateTo.value));

const {
  data: report,
  isLoading,
  isFetching,
  isError,
  error,
  refetch,
} = useThriftPeriodSalesReportQuery(tenantId, dateFromIso, dateToIso, saleChannel);

const reportsListPath = computed(
  () => `/${tenantSlug.value || 'tenant'}/app/thrift/reports`,
);

const summary = computed(() => report.value?.summary || {
  invoiceCount: 0,
  unitsSold: 0,
  netRevenue: 0,
  cogs: 0,
  lineProfit: 0,
  courierCodAmount: 0,
  otherExpenseAmount: 0,
  totalFees: 0,
  netAfterFees: 0,
  refundCount: 0,
  refundAmount: 0,
});

const codOutstanding = computed(() => report.value?.codOutstanding || {
  invoiceCount: 0,
  codExpectedTotal: 0,
  codRemittedTotal: 0,
});

const errorMessage = computed(() => {
  const err = error.value as { message?: string } | null;
  return err?.message || 'Failed to load sales report';
});

const channelOptions = [
  { label: 'All channels', value: null },
  { label: 'In-store', value: 'IN_STORE' },
  { label: 'Online', value: 'ONLINE' },
];

const channelColumns: QTableColumn[] = [
  { name: 'saleChannel', label: 'Channel', field: 'saleChannel', align: 'left' },
  { name: 'invoiceCount', label: 'Invoices', field: 'invoiceCount', align: 'right' },
  { name: 'unitsSold', label: 'Units', field: 'unitsSold', align: 'right' },
  { name: 'netRevenue', label: 'Revenue', field: 'netRevenue', align: 'right' },
  { name: 'cogs', label: 'COGS', field: 'cogs', align: 'right' },
  { name: 'lineProfit', label: 'Line profit', field: 'lineProfit', align: 'right' },
  { name: 'totalFees', label: 'Shop courier', field: 'totalFees', align: 'right' },
  { name: 'netAfterFees', label: 'Net after fees', field: 'netAfterFees', align: 'right' },
];
</script>

<style scoped>
.stat-card {
  height: 100%;
}
</style>
