<template>
  <q-page class="q-pa-md thrift-sales-page">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Thrift</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Sales & Invoices</h1>
        </div>
        <div class="col-auto row q-gutter-sm items-center">
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-plus"
            label="Create Invoice"
            :to="`/${authStore.tenantSlug || 'tenant'}/app/thrift/sales/create`"
          />
        </div>
      </section>

      <q-card flat bordered>
        <q-card-section class="q-pb-none">
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
        </q-card-section>

        <q-table
          flat
          :rows="rows"
          :columns="columns"
          row-key="id"
          v-model:pagination="tablePagination"
          :rows-per-page-options="[10, 20, 50]"
          :loading="loading"
          class="thrift-table cursor-pointer"
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
              </div>
              <span v-else class="text-grey-5">Walk-in</span>
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
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import { useQuasar, type QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import {
  thriftSalesRepository,
  type ThriftSalesInvoiceListItem,
} from '../repositories/thriftSalesRepository';

const $q = useQuasar();
const router = useRouter();
const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);

const loading = ref(false);
const search = ref('');
const rows = ref<ThriftSalesInvoiceListItem[]>([]);
const tablePagination = ref({ page: 1, rowsPerPage: 20 });

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
    sortable: true,
  },
  {
    name: 'customer',
    label: 'Customer',
    field: 'customerName',
    align: 'left',
    sortable: true,
  },
  {
    name: 'date',
    label: 'Date',
    field: 'date',
    align: 'left',
    sortable: true,
  },
  {
    name: 'itemCount',
    label: 'Items',
    field: 'itemCount',
    align: 'center',
    sortable: true,
  },
  {
    name: 'paymentMethod',
    label: 'Method',
    field: 'paymentMethod',
    align: 'left',
    sortable: true,
  },
  {
    name: 'paymentStatus',
    label: 'Payment',
    field: 'paymentStatus',
    align: 'left',
    sortable: true,
  },
  {
    name: 'status',
    label: 'Status',
    field: 'status',
    align: 'left',
    sortable: true,
  },
  {
    name: 'totalInvoiceAmount',
    label: 'Total',
    field: 'totalInvoiceAmount',
    align: 'right',
    sortable: true,
  },
  {
    name: 'createdBy',
    label: 'Cashier',
    field: 'createdBy',
    align: 'left',
    sortable: true,
  },
];

const resolvedTenantId = computed(() => tenantId.value || null);

function labelize(value: string): string {
  return (value || '—').replace(/_/g, ' ').toUpperCase();
}

function paymentStatusColor(status: string): string {
  const s = (status || '').toLowerCase();
  if (s === 'paid') return 'positive';
  if (s === 'partial') return 'warning';
  if (s === 'unpaid') return 'negative';
  if (s === 'refunded') return 'orange';
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

async function loadInvoices() {
  if (!resolvedTenantId.value) return;
  loading.value = true;
  try {
    rows.value = await thriftSalesRepository.listSalesInvoices(
      resolvedTenantId.value,
      search.value,
    );
  } catch (err: any) {
    $q.notify({
      type: 'negative',
      message: err?.message || 'Failed to load sales invoices',
    });
  } finally {
    loading.value = false;
  }
}

watch(search, () => {
  void loadInvoices();
});

watch(
  resolvedTenantId,
  (id) => {
    if (id) void loadInvoices();
  },
  { immediate: true },
);
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
