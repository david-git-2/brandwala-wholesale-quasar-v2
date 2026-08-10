<template>
  <q-page class="q-pa-md thrift-sales-page">
    <div class="q-gutter-y-md">
      <!-- Header Section -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Thrift</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Sales & Invoices</h1>
        </div>
        <div class="col-auto row q-gutter-sm items-center">
          <LearnMoreHelpBtn guide-id="thrift_sales" />
          <q-btn
            v-if="canCreate"
            color="primary"
            unelevated
            no-caps
            icon="ph ph-plus"
            label="Create Invoice"
            :to="`/${authStore.tenantSlug || 'tenant'}/app/thrift/sales/create`"
          />
        </div>
      </section>

      <!-- Initial Loading Skeleton -->
      <ThriftSalesSkeleton v-if="initialLoading" />

      <!-- Main Content Block -->
      <template v-else>
        <q-card flat bordered class="q-pa-sm">
          <div class="row items-center q-col-gutter-sm">
            <div class="col-12 col-sm-5 col-md-4">
              <q-input
                v-model="search"
                dense
                outlined
                clearable
                debounce="300"
                placeholder="Search invoice #, customer, phone…"
                class="search-input"
              >
                <template #prepend>
                  <q-icon name="ph ph-magnifying-glass" />
                </template>
              </q-input>
            </div>
            <div class="col-12 col-sm-4 col-md-3">
              <q-select
                v-model="paymentStatusFilter"
                dense
                outlined
                emit-value
                map-options
                :options="paymentStatusOptions"
                label="Payment status"
              />
            </div>
            <div class="col-12 col-sm-4 col-md-3">
              <q-select
                v-model="deliveryStatusFilter"
                dense
                outlined
                emit-value
                map-options
                clearable
                :options="deliveryStatusOptions"
                label="Delivery"
              />
            </div>
            <div class="col-12 col-sm-3 col-md-2">
              <q-select
                v-model="statusFilter"
                dense
                outlined
                emit-value
                map-options
                :options="statusOptions"
                label="Invoice status"
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

            <template #body-cell-invoiceNumber="props">
              <q-td :props="props">
                <router-link
                  :to="invoicePath(props.row.id)"
                  class="text-weight-bold text-primary"
                  style="text-decoration: none"
                  @click.stop
                >
                  {{ props.row.invoiceNumber }}
                </router-link>
              </q-td>
            </template>

            <template #body-cell-customer="props">
              <q-td :props="props">
                <div v-if="props.row.customerName || props.row.customerPhone">
                  <div class="text-weight-medium">{{ props.row.customerName || '—' }}</div>
                  <div v-if="props.row.customerPhone" class="text-caption text-grey-7">
                    {{ props.row.customerPhone }}
                  </div>
                  <div
                    v-if="props.row.customerAddress"
                    class="text-caption text-grey-6 ellipsis"
                    style="max-width: 220px"
                  >
                    {{ props.row.customerAddress }}
                  </div>
                </div>
                <span v-else class="text-grey-5">Walk-in</span>
              </q-td>
            </template>

            <template #body-cell-saleChannel="props">
              <q-td :props="props">
                <q-badge
                  outline
                  :color="saleChannelColor(props.row.saleChannel)"
                  :label="saleChannelLabel(props.row.saleChannel)"
                />
              </q-td>
            </template>

            <template #body-cell-date="props">
              <q-td :props="props">
                {{ formatDate(props.row.date) }}
              </q-td>
            </template>

            <template #body-cell-paymentMethod="props">
              <q-td :props="props">
                <q-badge outline color="grey-7" :label="labelize(props.row.paymentMethod)" />
              </q-td>
            </template>

            <template #body-cell-paymentStatus="props">
              <q-td :props="props">
                <q-badge
                  :color="paymentStatusColor(props.row.paymentStatus)"
                  :label="labelize(props.row.paymentStatus)"
                />
              </q-td>
            </template>

            <template #body-cell-deliveryStatus="props">
              <q-td :props="props">
                <q-badge
                  v-if="props.row.deliveryStatus"
                  outline
                  :color="deliveryStatusColor(props.row.deliveryStatus)"
                  :label="labelize(props.row.deliveryStatus)"
                />
                <span v-else class="text-grey-5">—</span>
              </q-td>
            </template>

            <template #body-cell-status="props">
              <q-td :props="props">
                <q-badge
                  :color="invoiceStatusColor(props.row.status)"
                  :label="labelize(props.row.status)"
                />
              </q-td>
            </template>

            <template #body-cell-totalInvoiceAmount="props">
              <q-td :props="props" class="text-right text-weight-bold">
                {{ formatThriftAmount(props.row.totalInvoiceAmount) }}
              </q-td>
            </template>

            <template #no-data>
              <div class="full-width column flex-center q-pa-xl text-grey-6">
                <q-icon name="ph ph-receipt" size="48px" class="q-mb-sm" />
                <div class="text-subtitle1 text-weight-medium">No invoices yet</div>
                <div class="text-body2 q-mb-md">Create a counter sale to see it listed here.</div>
                <q-btn
                  v-if="canCreate"
                  color="primary"
                  unelevated
                  no-caps
                  icon="ph ph-plus"
                  label="Create Invoice"
                  :to="`/${authStore.tenantSlug || 'tenant'}/app/thrift/sales/create`"
                />
              </div>
            </template>
          </q-table>
        </q-card>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import { type QTableColumn } from 'quasar';
import LearnMoreHelpBtn from 'src/modules/help/components/LearnMoreHelpBtn.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import { showErrorNotification } from 'src/utils/appFeedback';
import ThriftSalesSkeleton from '../components/ThriftSalesSkeleton.vue';
import {
  useThriftSalesInvoicesQuery,
  type ThriftSalesInvoiceListQueryParams,
} from '../composables/useThriftSalesQuery';
import type { ThriftSalesInvoiceListItem } from '../repositories/thriftSalesRepository';
import { formatThriftActionableError } from 'src/modules/thrift/shared/utils/formatThriftActionableError';

const router = useRouter();
const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);
const { hasModuleAccess } = useModulePermissions();

const canCreate = computed(() => hasModuleAccess('thrift_sales', 'create'));

const search = ref('');
const paymentStatusFilter = ref<string | null>(null);
const deliveryStatusFilter = ref<string | null>(null);
const statusFilter = ref<string | null>(null);
const page = ref(1);
const rowsPerPage = ref(20);

const paymentStatusOptions = [
  { label: 'All', value: null },
  { label: 'COD pending', value: 'COD_PENDING' },
  { label: 'Paid', value: 'PAID' },
  { label: 'Refunded', value: 'REFUNDED' },
  { label: 'Written off', value: 'WRITTEN_OFF' },
];

const deliveryStatusOptions = [
  { label: 'All', value: null },
  { label: 'Pending', value: 'PENDING' },
  { label: 'Ready', value: 'READY' },
  { label: 'In transit', value: 'IN_TRANSIT' },
  { label: 'Delivered', value: 'DELIVERED' },
  { label: 'Returned', value: 'RETURNED' },
];

const statusOptions = [
  { label: 'All', value: null },
  { label: 'Active', value: 'ACTIVE' },
  { label: 'Returned', value: 'RETURNED' },
];

const queryParams = computed<ThriftSalesInvoiceListQueryParams>(() => ({
  tenantId: tenantId.value || 0,
  search: search.value,
  page: page.value,
  pageSize: rowsPerPage.value,
  paymentStatus: paymentStatusFilter.value,
  deliveryStatus: deliveryStatusFilter.value,
  status: statusFilter.value,
}));

const {
  data: listData,
  isLoading: queryLoading,
  isFetching: queryFetching,
  isError,
  error,
  isFetched,
} = useThriftSalesInvoicesQuery(queryParams);

const initialLoading = computed(() => queryLoading.value && !isFetched.value);
const loading = computed(() => queryLoading.value || queryFetching.value);
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

const columns: QTableColumn[] = [
  {
    name: 'sl',
    label: 'SL',
    field: 'id',
    align: 'center',
    sortable: false,
    headerStyle: 'width: 50px',
  },
  {
    name: 'invoiceNumber',
    label: 'Invoice #',
    field: 'invoiceNumber',
    align: 'left',
    sortable: false,
  },
  {
    name: 'customer',
    label: 'Customer',
    field: 'customerName',
    align: 'left',
    sortable: false,
  },
  {
    name: 'saleChannel',
    label: 'Channel',
    field: 'saleChannel',
    align: 'left',
    sortable: false,
  },
  {
    name: 'date',
    label: 'Date',
    field: 'date',
    align: 'left',
    sortable: false,
  },
  {
    name: 'itemCount',
    label: 'Items',
    field: 'itemCount',
    align: 'center',
    sortable: false,
  },
  {
    name: 'paymentMethod',
    label: 'Method',
    field: 'paymentMethod',
    align: 'left',
    sortable: false,
  },
  {
    name: 'paymentStatus',
    label: 'Payment',
    field: 'paymentStatus',
    align: 'left',
    sortable: false,
  },
  {
    name: 'deliveryStatus',
    label: 'Delivery',
    field: 'deliveryStatus',
    align: 'left',
    sortable: false,
  },
  {
    name: 'status',
    label: 'Status',
    field: 'status',
    align: 'left',
    sortable: false,
  },
  {
    name: 'totalInvoiceAmount',
    label: 'Total',
    field: 'totalInvoiceAmount',
    align: 'right',
    sortable: false,
  },
  {
    name: 'createdBy',
    label: 'Cashier',
    field: 'createdBy',
    align: 'left',
    sortable: false,
  },
];

function labelize(value: string): string {
  return (value || '—').replace(/_/g, ' ').toUpperCase();
}

function saleChannelLabel(channel: string): string {
  return channel === 'ONLINE' ? 'Online' : 'In-store';
}

function saleChannelColor(channel: string): string {
  return channel === 'ONLINE' ? 'primary' : 'grey-7';
}

function paymentStatusColor(status: string): string {
  const s = (status || '').toLowerCase().replace(/-/g, '_');
  if (s === 'paid') return 'positive';
  if (s === 'cod_pending') return 'orange';
  if (s === 'partial') return 'warning';
  if (s === 'unpaid') return 'negative';
  if (s === 'refunded') return 'orange-8';
  if (s === 'written_off') return 'grey-8';
  return 'grey';
}

function deliveryStatusColor(status: string): string {
  const s = (status || '').toUpperCase();
  if (s === 'PENDING') return 'grey-7';
  if (s === 'READY') return 'primary';
  if (s === 'IN_TRANSIT') return 'blue-8';
  if (s === 'DELIVERED') return 'positive';
  if (s === 'RETURNED') return 'warning';
  return 'grey';
}

function invoiceStatusColor(status: string): string {
  const s = (status || '').toUpperCase();
  if (s === 'ACTIVE') return 'positive';
  if (s === 'RETURNED') return 'warning';
  if (s === 'STAFF_MISTAKE') return 'negative';
  return 'grey';
}

function formatDate(value: string): string {
  if (!value) return '—';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleString();
}

function invoicePath(id: number): string {
  return `/${tenantSlug.value || 'tenant'}/app/thrift/sales/${id}`;
}

function onRowClick(_evt: Event, row: ThriftSalesInvoiceListItem) {
  void router.push(invoicePath(row.id));
}

function onTableRequest(props: {
  pagination: { page: number; rowsPerPage: number; rowsNumber?: number };
}) {
  page.value = props.pagination.page;
  rowsPerPage.value = props.pagination.rowsPerPage;
}

watch(search, () => {
  page.value = 1;
});

watch(paymentStatusFilter, () => {
  page.value = 1;
});

watch(deliveryStatusFilter, () => {
  page.value = 1;
});

watch(statusFilter, () => {
  page.value = 1;
});

watch(isError, (failed) => {
  if (!failed || !error.value) return;
  showErrorNotification(
    formatThriftActionableError(error.value, 'Failed to load sales invoices'),
  );
});
</script>

<style scoped>
.thrift-sales-page {
  max-width: 1400px;
  margin: 0 auto;
}
.search-input {
  max-width: 360px;
}
.cursor-pointer :deep(tbody tr) {
  cursor: pointer;
}
</style>
