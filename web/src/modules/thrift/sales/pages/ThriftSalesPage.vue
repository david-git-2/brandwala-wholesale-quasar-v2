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
            flat
            no-caps
            label="Returns"
            :to="`/${authStore.tenantSlug || 'tenant'}/app/thrift/sales/returns`"
          />
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
          <div class="row q-gutter-sm q-mb-sm">
            <q-chip
              v-for="preset in listPresetOptions"
              :key="preset.value"
              clickable
              dense
              :outline="listPreset !== preset.value"
              :color="listPreset === preset.value ? 'primary' : 'grey-7'"
              :text-color="listPreset === preset.value ? 'white' : undefined"
              :label="preset.label"
              @click="setListPreset(preset.value)"
            />
          </div>
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

            <template #body-cell-statusSummary="props">
              <q-td :props="props">
                {{ statusSentence(props.row) }}
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
                <template v-if="filtersActive">
                  <div class="text-subtitle1 text-weight-medium">No matching invoices</div>
                  <div class="text-body2 q-mb-md">Try another filter or clear search.</div>
                  <q-btn
                    color="primary"
                    unelevated
                    no-caps
                    label="Clear filters"
                    @click="clearFilters"
                  />
                </template>
                <template v-else>
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
                </template>
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
import { useRoute, useRouter } from 'vue-router';
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

type ListPreset = 'active' | 'cod' | 'ready' | 'transit' | 'all' | 'custom';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);
const { hasModuleAccess } = useModulePermissions();

const canCreate = computed(() => hasModuleAccess('thrift_sales', 'create'));

const listPresetOptions: { label: string; value: Exclude<ListPreset, 'custom'> }[] = [
  { label: 'Active', value: 'active' },
  { label: 'COD waiting', value: 'cod' },
  { label: 'Ready', value: 'ready' },
  { label: 'In transit', value: 'transit' },
  { label: 'All', value: 'all' },
];

const listPreset = ref<ListPreset>('active');
const search = ref('');
const paymentStatusFilter = ref<string | null>(null);
const deliveryStatusFilter = ref<string | null>(null);
const statusFilter = ref<string | null>('ACTIVE');
const page = ref(1);
const rowsPerPage = ref(20);
let applyingPreset = false;

const paymentStatusOptions = [
  { label: 'All', value: null },
  { label: 'COD pending', value: 'COD_PENDING' },
  { label: 'Paid', value: 'PAID' },
  { label: 'Partially refunded', value: 'PARTIALLY_REFUNDED' },
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
  { label: 'Partially returned', value: 'PARTIALLY_RETURNED' },
  { label: 'Returned', value: 'RETURNED' },
];

function applyPresetFilters(preset: Exclude<ListPreset, 'custom'>) {
  applyingPreset = true;
  listPreset.value = preset;
  if (preset === 'active') {
    statusFilter.value = 'ACTIVE';
    paymentStatusFilter.value = null;
    deliveryStatusFilter.value = null;
  } else if (preset === 'cod') {
    statusFilter.value = 'ACTIVE';
    paymentStatusFilter.value = 'COD_PENDING';
    deliveryStatusFilter.value = null;
  } else if (preset === 'ready') {
    statusFilter.value = 'ACTIVE';
    paymentStatusFilter.value = null;
    deliveryStatusFilter.value = 'READY';
  } else if (preset === 'transit') {
    statusFilter.value = 'ACTIVE';
    paymentStatusFilter.value = null;
    deliveryStatusFilter.value = 'IN_TRANSIT';
  } else {
    statusFilter.value = null;
    paymentStatusFilter.value = null;
    deliveryStatusFilter.value = null;
  }
  page.value = 1;
  applyingPreset = false;
}

function setListPreset(preset: Exclude<ListPreset, 'custom'>) {
  applyPresetFilters(preset);
}

function clearFilters() {
  search.value = '';
  applyPresetFilters('active');
}

if (route.query.paymentStatus === 'COD_PENDING') {
  applyPresetFilters('cod');
}

const filtersActive = computed(() => {
  if (search.value.trim()) return true;
  if (listPreset.value !== 'active') return true;
  if (paymentStatusFilter.value) return true;
  if (deliveryStatusFilter.value) return true;
  if (statusFilter.value !== 'ACTIVE') return true;
  return false;
});

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
    name: 'statusSummary',
    label: 'Status',
    field: 'paymentStatus',
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

function statusSentence(row: ThriftSalesInvoiceListItem): string {
  const ch = row.saleChannel === 'ONLINE' ? 'Online' : 'In-store';
  const payMap: Record<string, string> = {
    COD_PENDING: 'Waiting for COD',
    PAID: 'Paid',
    PARTIALLY_REFUNDED: 'Partially refunded',
    REFUNDED: 'Refunded',
    WRITTEN_OFF: 'Written off',
  };
  const delMap: Record<string, string> = {
    PENDING: 'Pending',
    READY: 'Ready',
    IN_TRANSIT: 'In transit',
    DELIVERED: 'Delivered',
    RETURNED: 'Came back',
  };
  const pay = payMap[row.paymentStatus] || row.paymentStatus;
  if (row.deliveryStatus) {
    const del = delMap[row.deliveryStatus] || row.deliveryStatus;
    return `${ch} · ${del} · ${pay}`;
  }
  return `${ch} · ${pay}`;
}

function saleChannelLabel(channel: string): string {
  return channel === 'ONLINE' ? 'Online' : 'In-store';
}

function saleChannelColor(channel: string): string {
  return channel === 'ONLINE' ? 'primary' : 'grey-7';
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

watch([paymentStatusFilter, deliveryStatusFilter, statusFilter], () => {
  if (applyingPreset) return;
  listPreset.value = 'custom';
  page.value = 1;
}, { flush: 'sync' });

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
