<template>
  <q-page class="q-pa-md thrift-ledger-page">
    <div class="q-gutter-y-md">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-auto row items-center q-gutter-x-sm">
          <q-btn flat round dense icon="ph ph-arrow-left" color="primary" :to="reportsListPath">
            <q-tooltip>Back to Reports</q-tooltip>
          </q-btn>
          <div>
            <div class="text-overline text-primary">Thrift / Reports</div>
            <h1 class="text-h5 text-weight-bold q-my-none">Ledger</h1>
            <div class="text-body2 text-grey-7 q-mt-xs">
              Read-only thrift accounting entries
            </div>
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
              v-model="typeFilter"
              :options="typeOptions"
              label="Type"
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

      <div v-if="initialLoading" class="column flex-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
      </div>

      <div v-else-if="isError" class="bg-negative text-white q-pa-md rounded-borders">
        {{ errorMessage }}
      </div>

      <q-card v-else flat bordered>
        <q-table
          flat
          dense
          :rows="rows"
          :columns="columns"
          row-key="id"
          v-model:pagination="tablePagination"
          :rows-per-page-options="[25, 50, 100]"
          :loading="loading"
          class="thrift-table"
          @request="onTableRequest"
        >
          <template #body-cell-date="props">
            <q-td :props="props">
              {{ formatDate(props.row.date) }}
            </q-td>
          </template>

          <template #body-cell-type="props">
            <q-td :props="props">
              <q-badge :color="typeColor(props.row.type)" :label="props.row.type" />
            </q-td>
          </template>

          <template #body-cell-source="props">
            <q-td :props="props">
              <q-badge outline color="grey-7" :label="props.row.source" />
            </q-td>
          </template>

          <template #body-cell-amount="props">
            <q-td :props="props" class="text-right text-weight-bold">
              <span :class="amountClass(props.row.type)">
                {{ formatThriftAmount(props.row.amount) }}
              </span>
            </q-td>
          </template>

          <template #body-cell-note="props">
            <q-td :props="props">
              <span class="ellipsis" style="max-width: 240px; display: inline-block">
                {{ props.row.note || '—' }}
              </span>
            </q-td>
          </template>

          <template #no-data>
            <div class="full-width column flex-center q-pa-xl text-grey-6">
              <q-icon name="ph ph-book-open" size="48px" class="q-mb-sm" />
              <div class="text-subtitle1 text-weight-medium">No ledger entries</div>
              <div class="text-body2">
                Create or revert a thrift sale to see entries in this range.
              </div>
            </div>
          </template>
        </q-table>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { storeToRefs } from 'pinia';
import type { QTableColumn, QTableProps } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import { formatThriftActionableError } from 'src/modules/thrift/shared/utils/formatThriftActionableError';
import {
  useThriftLedgerQuery,
  type ThriftLedgerListQueryParams,
} from '../composables/useThriftLedgerQuery';
import type { ThriftLedgerType } from '../repositories/thriftLedgerRepository';

function todayIsoDate(): string {
  return new Date().toISOString().slice(0, 10);
}

function daysAgoIsoDate(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() - days);
  return d.toISOString().slice(0, 10);
}

const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);

const dateFrom = ref(daysAgoIsoDate(30));
const dateTo = ref(todayIsoDate());
const typeFilter = ref<ThriftLedgerType | null>(null);
const page = ref(1);
const rowsPerPage = ref(25);

const typeOptions = [
  { label: 'All types', value: null },
  { label: 'Revenue', value: 'REVENUE' },
  { label: 'Expense', value: 'EXPENSE' },
  { label: 'Refund', value: 'REFUND' },
  { label: 'Loss', value: 'LOSS' },
];

const queryParams = computed<ThriftLedgerListQueryParams>(() => ({
  tenantId: tenantId.value || 0,
  dateFrom: dateFrom.value,
  dateTo: dateTo.value,
  type: typeFilter.value,
  page: page.value,
  pageSize: rowsPerPage.value,
}));

const {
  data: listData,
  isLoading: queryLoading,
  isFetching,
  isError,
  error,
  isFetched,
  refetch,
} = useThriftLedgerQuery(queryParams);

const initialLoading = computed(() => queryLoading.value && !isFetched.value);
const loading = computed(() => queryLoading.value || isFetching.value);
const rows = computed(() => listData.value?.data ?? []);

const errorMessage = computed(() =>
  formatThriftActionableError(error.value, 'Failed to load ledger entries'),
);

const reportsListPath = computed(
  () => `/${tenantSlug.value || 'tenant'}/app/thrift/reports`,
);

const tablePagination = computed({
  get: () => ({
    page: page.value,
    rowsPerPage: rowsPerPage.value,
    rowsNumber: listData.value?.meta.total ?? 0,
  }),
  set: (val: { page: number; rowsPerPage: number; rowsNumber?: number }) => {
    page.value = val.page;
    rowsPerPage.value = val.rowsPerPage;
  },
});

const columns: QTableColumn[] = [
  { name: 'date', label: 'Date', field: 'date', align: 'left' },
  { name: 'type', label: 'Type', field: 'type', align: 'left' },
  { name: 'source', label: 'Source', field: 'source', align: 'left' },
  { name: 'amount', label: 'Amount', field: 'amount', align: 'right' },
  { name: 'referenceId', label: 'Reference', field: 'referenceId', align: 'left' },
  { name: 'note', label: 'Note', field: 'note', align: 'left' },
];

watch([dateFrom, dateTo, typeFilter], () => {
  page.value = 1;
});

function onTableRequest(req: Parameters<NonNullable<QTableProps['onRequest']>>[0]) {
  page.value = req.pagination.page ?? 1;
  rowsPerPage.value = req.pagination.rowsPerPage ?? 25;
}

function formatDate(value: string) {
  if (!value) return '—';
  try {
    return new Date(value).toLocaleDateString();
  } catch {
    return value;
  }
}

function typeColor(type: ThriftLedgerType): string {
  switch (type) {
    case 'REVENUE':
      return 'positive';
    case 'EXPENSE':
      return 'orange';
    case 'REFUND':
      return 'warning';
    case 'LOSS':
      return 'negative';
    default:
      return 'grey-7';
  }
}

function amountClass(type: ThriftLedgerType): string {
  if (type === 'REVENUE') return 'text-positive';
  if (type === 'REFUND' || type === 'LOSS' || type === 'EXPENSE') return 'text-negative';
  return '';
}
</script>
