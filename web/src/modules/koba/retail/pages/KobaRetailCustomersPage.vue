<template>
  <q-page class="q-pa-md bw-page">
    <!-- Header Section -->
    <div class="row items-center justify-between q-mb-md">
      <div>
        <div class="text-h5 text-weight-bold text-grey-9">Koba Retail Customers</div>
        <div class="text-caption text-grey-7">
          Track customer demand, metrics, and ordering frequency
        </div>
      </div>
      <q-btn
        flat
        round
        color="grey-8"
        icon="arrow_back"
        :to="{ name: 'app-koba-retail-page' }"
        hint="Back to Products"
      />
    </div>

    <!-- Search & Filter Controls -->
    <q-card flat bordered class="q-mb-md filter-card">
      <q-card-section class="q-py-md">
        <div class="row q-col-gutter-sm items-center">
          <div class="col-12 col-sm-6 col-md-4">
            <q-input
              v-model="search"
              placeholder="Search by Name or Phone..."
              outlined
              dense
              clearable
              class="soft-input"
              @update:model-value="onSearch"
            >
              <template #prepend>
                <q-icon name="search" color="grey-6" />
              </template>
            </q-input>
          </div>
          <div class="col text-right">
            <q-btn
              flat
              color="primary"
              icon="refresh"
              label="Reload"
              no-caps
              :loading="loading"
              @click="fetchCustomers"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Table Grid -->
    <q-card flat bordered class="table-card">
      <q-table
        :rows="customers"
        :columns="columns"
        row-key="phone"
        :loading="loading"
        :pagination="pagination"
        flat
        binary-state-sort
        class="bw-table"
        no-data-label="No customers found"
      >
        <!-- Customer Name Column -->
        <template #body-cell-name="props">
          <q-td :props="props">
            <div class="row items-center q-gutter-xs">
              <q-avatar size="28px" color="primary" text-color="white" class="text-weight-bold">
                {{ (props.row.name || 'C').charAt(0).toUpperCase() }}
              </q-avatar>
              <div class="q-ml-sm">
                <div class="text-weight-medium text-grey-9">
                  {{ props.row.name || 'Walk-in Customer' }}
                </div>
                <div class="text-caption text-grey-5">{{ props.row.phone }}</div>
              </div>
            </div>
          </q-td>
        </template>

        <!-- Location Column -->
        <template #body-cell-location="props">
          <q-td :props="props">
            <div v-if="props.row.district" class="text-grey-8">
              {{ props.row.district }}
              <span v-if="props.row.thana" class="text-grey-6 text-caption"
                >({{ props.row.thana }})</span
              >
            </div>
            <div v-else class="text-grey-4">-</div>
          </q-td>
        </template>

        <!-- Total Spent Column -->
        <template #body-cell-total_spent="props">
          <q-td :props="props" class="text-weight-medium text-positive">
            ৳{{ Number(props.row.total_spent || 0).toFixed(2) }}
          </q-td>
        </template>

        <!-- Last Order Date Column -->
        <template #body-cell-last_order_date="props">
          <q-td :props="props" class="text-grey-8">
            {{ formatDate(props.row.last_order_date) }}
          </q-td>
        </template>

        <!-- Actions Column -->
        <template #body-cell-actions="props">
          <q-td :props="props" align="right">
            <q-btn
              flat
              round
              color="primary"
              icon="analytics"
              size="sm"
              :to="{
                name: 'app-koba-retail-customer-profile-page',
                params: { phone: props.row.phone },
              }"
            >
              <q-tooltip>View Profile & Analytics</q-tooltip>
            </q-btn>
          </q-td>
        </template>
      </q-table>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { date, useQuasar, type QTableColumn } from 'quasar';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

interface CustomerRow {
  phone: string;
  name: string;
  district: string;
  thana: string;
  address: string;
  total_orders: number;
  total_spent: number;
  last_order_date: string;
}

const $q = useQuasar();
const authStore = useAuthStore();

const loading = ref(false);
const search = ref('');
const customers = ref<CustomerRow[]>([]);

const pagination = ref({
  sortBy: 'last_order_date',
  descending: true,
  page: 1,
  rowsPerPage: 15,
});

const columns: QTableColumn[] = [
  { name: 'name', label: 'Customer', align: 'left', field: 'name', sortable: true },
  { name: 'location', label: 'Primary Location', align: 'left', field: 'district', sortable: true },
  { name: 'total_orders', label: 'Orders', align: 'center', field: 'total_orders', sortable: true },
  {
    name: 'total_spent',
    label: 'Total Spent',
    align: 'left',
    field: 'total_spent',
    sortable: true,
  },
  {
    name: 'last_order_date',
    label: 'Last Active',
    align: 'left',
    field: 'last_order_date',
    sortable: true,
  },
  { name: 'actions', label: 'Actions', align: 'right', field: 'actions' },
];

const tenantId = computed(() => authStore.tenantId);

async function fetchCustomers() {
  if (!tenantId.value) return;
  loading.value = true;
  try {
    const { data, error } = await supabase.rpc('get_koba_customers_list', {
      p_tenant_id: tenantId.value,
      p_search: search.value || null,
      p_limit: 1000,
      p_offset: 0,
    });

    if (error) {
      $q.notify({ type: 'negative', message: error.message || 'Failed to load customers' });
      return;
    }

    customers.value = (data || []) as CustomerRow[];
  } catch (err: unknown) {
    const error = err as Error;
    $q.notify({ type: 'negative', message: error.message || 'Unexpected error loading customers' });
  } finally {
    loading.value = false;
  }
}

let searchTimeout: ReturnType<typeof setTimeout> | null = null;
function onSearch() {
  if (searchTimeout) clearTimeout(searchTimeout);
  searchTimeout = setTimeout(() => {
    void fetchCustomers();
  }, 350);
}

function formatDate(val: string | null) {
  if (!val) return '-';
  return date.formatDate(new Date(val), 'YYYY-MM-DD HH:mm');
}

onMounted(() => {
  void fetchCustomers();
});
</script>

<style scoped>
.bw-page {
  background: #f8fafc;
}
.filter-card {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.9);
}
.table-card {
  border-radius: 12px;
  background: white;
  overflow: hidden;
}
.soft-input :deep(.q-field__control) {
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.8);
}
.bw-table :deep(th) {
  font-weight: 700;
  color: var(--q-grey-9);
  background: #f1f5f9;
}
</style>
