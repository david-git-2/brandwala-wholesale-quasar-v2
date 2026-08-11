<template>
  <q-page class="q-pa-md thrift-returns-page">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Thrift / Sales</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Returns</h1>
          <div class="text-caption text-grey-7 q-mt-xs">
            Post-pay returns (not Mark RTO). Create from an invoice → Return items.
          </div>
        </div>
      </section>

      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center q-col-gutter-sm">
          <div class="col-12 col-sm-5 col-md-4">
            <q-input
              v-model="search"
              dense
              outlined
              clearable
              debounce="300"
              placeholder="Search return #, invoice #, phone…"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
          </div>
          <div class="col-6 col-sm-3 col-md-2">
            <q-input v-model="dateFrom" dense outlined type="date" label="From" />
          </div>
          <div class="col-6 col-sm-3 col-md-2">
            <q-input v-model="dateTo" dense outlined type="date" label="To" />
          </div>
          <div class="col-12 col-sm-3 col-md-2">
            <q-select
              v-model="damagedFilter"
              dense
              outlined
              emit-value
              map-options
              :options="damagedOptions"
              label="Condition"
            />
          </div>
        </div>
      </q-card>

      <q-card flat bordered>
        <q-table
          flat
          :rows="rows"
          :columns="columns"
          row-key="id"
          v-model:pagination="tablePagination"
          :rows-per-page-options="[10, 20, 50]"
          :loading="loading"
          class="thrift-table cursor-pointer"
          @request="onTableRequest"
          @row-click="onRowClick"
        >
          <template #body-cell-sl="props">
            <q-td :props="props">
              {{ (tablePagination.page - 1) * tablePagination.rowsPerPage + props.rowIndex + 1 }}
            </q-td>
          </template>
          <template #body-cell-refundAmount="props">
            <q-td :props="props" class="text-right text-weight-medium">
              {{ formatThriftAmount(props.row.refundAmount) }}
            </q-td>
          </template>
          <template #body-cell-returnCourierAmount="props">
            <q-td :props="props" class="text-right">
              {{ formatThriftAmount(props.row.returnCourierAmount) }}
            </q-td>
          </template>
          <template #body-cell-hasDamaged="props">
            <q-td :props="props">
              <q-badge
                v-if="props.row.hasDamaged"
                color="negative"
                outline
                label="Damaged"
              />
              <span v-else class="text-grey-6">—</span>
            </q-td>
          </template>
          <template #body-cell-createdAt="props">
            <q-td :props="props">
              {{ formatDate(props.row.createdAt) }}
            </q-td>
          </template>
          <template #no-data>
            <div class="full-width column flex-center q-pa-lg text-grey-6">
              No returns found.
            </div>
          </template>
        </q-table>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import type { QTableColumn, QTableProps } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import { showErrorNotification } from 'src/utils/appFeedback';
import { useThriftSalesReturnsQuery } from '../composables/useThriftSalesQuery';
import type {
  ListSalesReturnsParams,
  ThriftSalesReturnListItem,
} from '../repositories/thriftSalesRepository';
import { formatThriftActionableError } from 'src/modules/thrift/shared/utils/formatThriftActionableError';

function startOfMonthIsoDate(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`;
}

function todayIsoDate(): string {
  return new Date().toISOString().slice(0, 10);
}

function dayStartIso(date: string): string | null {
  if (!date) return null;
  return new Date(`${date}T00:00:00`).toISOString();
}

function dayEndIso(date: string): string | null {
  if (!date) return null;
  return new Date(`${date}T23:59:59.999`).toISOString();
}

const router = useRouter();
const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);

const search = ref('');
const dateFrom = ref(startOfMonthIsoDate());
const dateTo = ref(todayIsoDate());
const damagedFilter = ref<boolean | null>(null);
const page = ref(1);
const rowsPerPage = ref(20);

const damagedOptions = [
  { label: 'All', value: null },
  { label: 'Has damaged', value: true },
  { label: 'Sellable only', value: false },
];

const queryParams = computed<ListSalesReturnsParams>(() => ({
  tenantId: tenantId.value || 0,
  search: search.value,
  page: page.value,
  pageSize: rowsPerPage.value,
  dateFrom: dayStartIso(dateFrom.value),
  dateTo: dayEndIso(dateTo.value),
  hasDamaged: damagedFilter.value,
}));

const {
  data: listData,
  isLoading,
  isFetching,
  isError,
  error,
} = useThriftSalesReturnsQuery(queryParams);

const loading = computed(() => isLoading.value || isFetching.value);
const rows = computed(() => listData.value?.data ?? []);

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

const columns: QTableColumn<ThriftSalesReturnListItem>[] = [
  { name: 'sl', label: '#', field: 'id', align: 'left', style: 'width: 48px' },
  { name: 'returnNumber', label: 'Return #', field: 'returnNumber', align: 'left' },
  { name: 'invoiceNumber', label: 'Invoice', field: 'invoiceNumber', align: 'left' },
  {
    name: 'customer',
    label: 'Customer',
    field: (row) => row.customerName || row.customerPhone || '—',
    align: 'left',
  },
  { name: 'lineCount', label: 'Lines', field: 'lineCount', align: 'center' },
  { name: 'refundAmount', label: 'Refund', field: 'refundAmount', align: 'right' },
  {
    name: 'returnCourierAmount',
    label: 'Courier loss',
    field: 'returnCourierAmount',
    align: 'right',
  },
  { name: 'hasDamaged', label: 'Condition', field: 'hasDamaged', align: 'left' },
  { name: 'createdAt', label: 'Created', field: 'createdAt', align: 'left' },
];

function formatDate(value: string): string {
  if (!value) return '—';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleString();
}

function onTableRequest(req: Parameters<NonNullable<QTableProps['onRequest']>>[0]) {
  page.value = req.pagination?.page || 1;
  rowsPerPage.value = req.pagination?.rowsPerPage || 20;
}

function onRowClick(_evt: Event, row: ThriftSalesReturnListItem) {
  void router.push(`/${tenantSlug.value || 'tenant'}/app/thrift/sales/returns/${row.id}`);
}

watch([search, dateFrom, dateTo, damagedFilter], () => {
  page.value = 1;
});

watch(isError, (err) => {
  if (err) {
    showErrorNotification(
      formatThriftActionableError(error.value, 'Failed to load returns'),
    );
  }
});
</script>
