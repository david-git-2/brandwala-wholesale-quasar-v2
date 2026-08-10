<template>
  <q-page class="q-pa-md thrift-reports-page">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Thrift</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Reports</h1>
          <div class="text-body2 text-grey-7 q-mt-xs">
            Period sales summary or per-shipment profit.
          </div>
        </div>
      </section>

      <div v-if="metricsLoading" class="row q-col-gutter-md">
        <div v-for="n in 7" :key="n" class="col-6 col-sm-4 col-md">
          <q-card flat bordered class="stat-card">
            <q-card-section class="flex flex-center" style="min-height: 72px">
              <q-spinner color="primary" size="24px" />
            </q-card-section>
          </q-card>
        </div>
      </div>

      <div v-else-if="metricsError" class="bg-negative text-white q-pa-md rounded-borders">
        {{ metricsErrorMessage }}
      </div>

      <div v-else-if="metrics" class="row q-col-gutter-md">
        <div class="col-6 col-sm-4 col-md">
          <q-card flat bordered class="stat-card">
            <q-card-section>
              <div class="text-caption text-grey-6">Added today</div>
              <div class="text-h6 text-weight-bold">{{ metrics.itemsAddedToday }}</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-6 col-sm-4 col-md">
          <q-card flat bordered class="stat-card">
            <q-card-section>
              <div class="text-caption text-grey-6">Total items</div>
              <div class="text-h6 text-weight-bold">{{ metrics.totalItems }}</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-6 col-sm-4 col-md">
          <q-card flat bordered class="stat-card">
            <q-card-section>
              <div class="text-caption text-grey-6">Available</div>
              <div class="text-h6 text-weight-bold text-positive">{{ metrics.availableItems }}</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-6 col-sm-4 col-md">
          <q-card flat bordered class="stat-card">
            <q-card-section>
              <div class="text-caption text-grey-6">Sold</div>
              <div class="text-h6 text-weight-bold">{{ metrics.soldItems }}</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-6 col-sm-4 col-md">
          <q-card flat bordered class="stat-card">
            <q-card-section>
              <div class="text-caption text-grey-6">Invoices today</div>
              <div class="text-h6 text-weight-bold">{{ metrics.activeInvoicesToday }}</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-6 col-sm-4 col-md">
          <q-card flat bordered class="stat-card">
            <q-card-section>
              <div class="text-caption text-grey-6">COD pending</div>
              <div class="text-h6 text-weight-bold text-warning">{{ metrics.codPendingCount }}</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-6 col-sm-4 col-md">
          <q-card flat bordered class="stat-card">
            <q-card-section>
              <div class="text-caption text-grey-6">COD expected</div>
              <div class="text-h6 text-weight-bold text-warning">
                {{ formatThriftAmount(metrics.codExpectedTotal) }}
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <div class="row q-col-gutter-md">
        <div class="col-12 col-sm-4">
          <q-card flat bordered class="hub-card cursor-pointer" @click="goSalesReport">
            <q-card-section class="row items-center q-gutter-md">
              <q-avatar color="primary" text-color="white" icon="ph ph-calendar" />
              <div class="col">
                <div class="text-subtitle1 text-weight-bold">Sales report</div>
                <div class="text-body2 text-grey-7">
                  Date range · channel · COGS · COD
                </div>
              </div>
              <q-icon name="ph ph-caret-right" color="grey-6" />
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-sm-4">
          <q-card flat bordered class="hub-card cursor-pointer" @click="goLedger">
            <q-card-section class="row items-center q-gutter-md">
              <q-avatar color="secondary" text-color="white" icon="ph ph-book-open" />
              <div class="col">
                <div class="text-subtitle1 text-weight-bold">Ledger</div>
                <div class="text-body2 text-grey-7">
                  Read-only thrift accounting entries
                </div>
              </div>
              <q-icon name="ph ph-caret-right" color="grey-6" />
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-sm-4">
          <q-card flat bordered class="hub-card">
            <q-card-section class="row items-center q-gutter-md">
              <q-avatar color="grey-8" text-color="white" icon="ph ph-package" />
              <div class="col">
                <div class="text-subtitle1 text-weight-bold">Shipment reports</div>
                <div class="text-body2 text-grey-7">
                  Pick a shipment below for sales &amp; profit
                </div>
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <q-card flat bordered>
        <q-card-section class="q-pb-none">
          <div class="text-subtitle2 text-weight-bold q-mb-sm">Shipments</div>
          <q-input
            v-model="search"
            dense
            outlined
            clearable
            debounce="200"
            placeholder="Search shipments…"
            class="search-input"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" />
            </template>
          </q-input>
        </q-card-section>

        <q-table
          flat
          :rows="filteredRows"
          :columns="columns"
          row-key="id"
          v-model:pagination="tablePagination"
          :rows-per-page-options="[10, 20, 50]"
          :loading="isLoading"
          class="thrift-table cursor-pointer"
          @row-click="onRowClick"
        >
          <template #body-cell-sl="props">
            <q-td :props="props">
              {{ (tablePagination.page - 1) * tablePagination.rowsPerPage + props.rowIndex + 1 }}
            </q-td>
          </template>

          <template #body-cell-name="props">
            <q-td :props="props">
              <router-link
                :to="reportPath(props.row.id)"
                class="text-weight-bold text-primary"
                style="text-decoration: none"
                @click.stop
              >
                {{ props.row.name }}
              </router-link>
            </q-td>
          </template>

          <template #body-cell-created_at="props">
            <q-td :props="props">
              {{ formatDate(props.row.created_at) }}
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right">
              <q-btn
                flat
                round
                dense
                color="primary"
                icon="ph ph-chart-bar"
                :to="reportPath(props.row.id)"
                @click.stop
              >
                <q-tooltip>View sales &amp; profit</q-tooltip>
              </q-btn>
            </q-td>
          </template>

          <template #no-data>
            <div class="full-width column flex-center q-pa-xl text-grey-6">
              <q-icon name="ph ph-chart-bar" size="48px" class="q-mb-sm" />
              <div class="text-subtitle1 text-weight-medium">No shipments yet</div>
              <div class="text-body2">Create a thrift shipment to run sales reports against it.</div>
            </div>
          </template>
        </q-table>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import type { QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import type { ThriftShipment } from '../../shipment/types';
import {
  useThriftDashboardMetricsQuery,
  useThriftReportShipmentsQuery,
} from '../composables/useThriftReportsQuery';

const router = useRouter();
const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);

const search = ref('');
const tablePagination = ref({ page: 1, rowsPerPage: 20 });

const { data: shipments, isLoading } = useThriftReportShipmentsQuery(tenantId);
const {
  data: metrics,
  isLoading: metricsLoading,
  isError: metricsError,
  error: metricsErr,
} = useThriftDashboardMetricsQuery(tenantId);

const metricsErrorMessage = computed(() => {
  const err = metricsErr.value as { message?: string } | null;
  return err?.message || 'Failed to load dashboard metrics';
});

const columns: QTableColumn[] = [
  { name: 'sl', label: '#', field: 'id', align: 'left', style: 'width: 48px' },
  { name: 'name', label: 'Shipment', field: 'name', align: 'left', sortable: true },
  {
    name: 'created_at',
    label: 'Created',
    field: 'created_at',
    align: 'left',
    sortable: true,
  },
  { name: 'actions', label: '', field: 'id', align: 'right', style: 'width: 64px' },
];

const filteredRows = computed(() => {
  const q = search.value.trim().toLowerCase();
  const rows = shipments.value || [];
  if (!q) return rows;
  return rows.filter((row) => row.name?.toLowerCase().includes(q) || String(row.id).includes(q));
});

function reportPath(id: number) {
  return `/${tenantSlug.value || 'tenant'}/app/thrift/reports/${id}`;
}

function salesReportPath() {
  return `/${tenantSlug.value || 'tenant'}/app/thrift/reports/sales`;
}

function ledgerPath() {
  return `/${tenantSlug.value || 'tenant'}/app/thrift/ledger`;
}

function goSalesReport() {
  void router.push(salesReportPath());
}

function goLedger() {
  void router.push(ledgerPath());
}

function formatDate(value: string) {
  if (!value) return '—';
  try {
    return new Date(value).toLocaleString();
  } catch {
    return value;
  }
}

function onRowClick(_evt: Event, row: ThriftShipment) {
  void router.push(reportPath(row.id));
}
</script>

<style scoped>
.hub-card {
  transition: border-color 0.15s ease;
}
.hub-card:hover {
  border-color: var(--q-primary);
}
.stat-card {
  height: 100%;
}
</style>
