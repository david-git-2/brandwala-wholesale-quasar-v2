<template>
  <q-page class="bw-page q-pa-md">
    <!-- Header -->
    <div class="orders-header q-mb-md">
      <div class="row items-center q-gutter-sm">
        <q-btn flat round icon="arrow_back" color="grey-8" :to="{ name: productsRouteName }" />
        <div>
          <div class="text-h5 text-weight-bold">Orders</div>
          <div class="text-caption text-grey-7">
            Manage your placed Koba retail orders
          </div>
        </div>
      </div>
      <div>
        <q-btn
          color="primary"
          icon="shopping_cart"
          label="Back to Shop"
          no-caps
          unelevated
          :to="{ name: productsRouteName }"
        />
      </div>
    </div>

    <!-- Filter status toolbar -->
    <div class="row items-center q-gutter-sm q-mb-md">
      <!-- Sidebar Toggle Button -->
      <q-btn flat round dense icon="filter_alt" color="primary" aria-label="Filters" @click="filterDrawerOpen = true">
        <q-badge v-if="filterStatus" color="primary" rounded floating>1</q-badge>
      </q-btn>

      <!-- Active filter count + clear -->
      <div v-if="filterStatus" class="row items-center q-gutter-xs">
        <q-chip dense color="primary" text-color="white" label="1 filter" />
        <q-btn flat dense no-caps size="sm" icon="close" label="Clear" color="grey-7" @click="onClearDrawerFilters" />
      </div>
    </div>

    <!-- Filter Sidebar Drawer -->
    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <q-select
        v-model="filterStatus"
        :options="statusOptions"
        outlined dense
        label="Status"
        class="soft-input q-mb-md"
        clearable
        emit-value
        map-options
      />

      <div class="row q-gutter-sm justify-end">
        <q-btn flat no-caps label="Reset" @click="onResetDrawerFilters" />
        <q-btn flat no-caps label="Apply" color="primary" @click="onApplyDrawerFilters" />
      </div>
    </FilterSidebar>

    <!-- Loading -->
    <PageInitialLoader v-if="store.loading && store.orders.length === 0" />

    <!-- Empty State -->
    <div v-else-if="store.orders.length === 0" class="empty-state-card q-pa-xl text-center">
      <q-icon name="receipt_long" size="64px" color="grey-4" class="q-mb-md" />
      <div class="text-h6 text-grey-8 text-weight-medium">No orders found</div>
      <div class="text-caption text-grey-6">You haven't placed any orders yet.</div>
    </div>

    <!-- Orders Table -->
    <q-card v-else flat class="orders-table-card">
      <q-table
        flat
        :rows="store.orders"
        :columns="tableColumns"
        row-key="id"
        :loading="store.loading"
        :pagination="serverPagination"
        class="orders-table"
        @request="onTableRequest"
      >
        <template #body="sp">
          <q-tr :props="sp" class="order-row cursor-pointer" @click="viewOrderDetails(sp.row.id)">
            <q-td key="id" :props="sp">
              <span class="text-weight-bold text-primary">#{{ sp.row.id }}</span>
            </q-td>
            <q-td key="recipient" :props="sp">
              <div class="text-weight-medium">{{ sp.row.shipping_name || '—' }}</div>
              <div class="text-caption text-grey-6">{{ sp.row.shipping_phone || '—' }}</div>
            </q-td>
            <q-td key="status" :props="sp">
              <q-chip
                dense
                square
                :style="statusChipStyle(sp.row.status)"
                class="costing-file-status-chip"
              >
                <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(sp.row.status) }" />
                {{ sp.row.status }}
              </q-chip>
            </q-td>
          </q-tr>
        </template>
      </q-table>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import type { QTableColumn } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useKobaOrderStore } from 'src/modules/koba/retail/stores/kobaOrderStore'
import type { KobaOrderStatus } from 'src/modules/koba/retail/repositories/kobaOrderRepository'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import FilterSidebar from 'src/components/FilterSidebar.vue'

const authStore = useAuthStore()
const store = useKobaOrderStore()

const productsRouteName = computed(() => {
  return authStore.scope === 'shop' ? 'shop-koba-retail-page' : 'app-koba-retail-page'
})

const filterStatus = ref<KobaOrderStatus | null>(null)
const filterDrawerOpen = ref(false)

const statusOptions = [
  { label: 'Pending', value: 'pending' },
  { label: 'Confirmed', value: 'confirmed' },
  { label: 'Processing', value: 'processing' },
  { label: 'Shipped', value: 'shipped' },
  { label: 'Delivered', value: 'delivered' },
  { label: 'Cancelled', value: 'cancelled' },
]

onMounted(async () => {
  await store.fetchOrders(1)
})

const serverPagination = computed(() => ({
  page: store.meta.page,
  rowsPerPage: store.meta.page_size,
  rowsNumber: store.meta.total,
}))

async function onApplyDrawerFilters() {
  filterDrawerOpen.value = false
  await store.fetchOrders(1, filterStatus.value)
}

function onResetDrawerFilters() {
  filterStatus.value = null
}

async function onClearDrawerFilters() {
  filterStatus.value = null
  filterDrawerOpen.value = false
  await store.fetchOrders(1, null)
}

async function onTableRequest(payload: { pagination: { page: number; rowsPerPage: number } }) {
  store.meta.page_size = payload.pagination.rowsPerPage
  await store.fetchOrders(payload.pagination.page, filterStatus.value)
}

const router = useRouter()

function viewOrderDetails(orderId: number) {
  const routeName = authStore.scope === 'shop' ? 'shop-koba-retail-order-detail-page' : 'app-koba-retail-order-detail-page'
  void router.push({ name: routeName, params: { id: String(orderId) } })
}


const statusChipStyle = (currentStatus: string | null) => {
  const value = (currentStatus ?? '').toLowerCase()
  if (value === 'pending') {
    return {
      backgroundColor: '#efd399',
      color: '#6a4a14',
      border: '1px solid #d8b672',
    }
  }
  if (value === 'confirmed') {
    return {
      backgroundColor: '#c8d8f8',
      color: '#27487a',
      border: '1px solid #a9c4f3',
    }
  }
  if (value === 'processing') {
    return {
      backgroundColor: '#e8eaf6',
      color: '#283593',
      border: '1px solid #c5cae9',
    }
  }
  if (value === 'shipped') {
    return {
      backgroundColor: '#c3e8d2',
      color: '#1f5d3c',
      border: '1px solid #9fd4b7',
    }
  }
  if (value === 'delivered') {
    return {
      backgroundColor: '#e0f2f1',
      color: '#00695c',
      border: '1px solid #b2dfdb',
    }
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#f2c7d0',
      color: '#6f2b3a',
      border: '1px solid #e3a6b3',
    }
  }
  return {
    backgroundColor: '#dbe5f3',
    color: '#3b4b66',
    border: '1px solid #b9c8dd',
  }
}

const statusDotColor = (currentStatus: string | null) => {
  const value = (currentStatus ?? '').toLowerCase()
  if (value === 'pending') return '#9a6a24'
  if (value === 'confirmed') return '#3f67b3'
  if (value === 'processing') return '#3f51b5'
  if (value === 'shipped') return '#2f8b5d'
  if (value === 'delivered') return '#009688'
  if (value === 'cancelled') return '#a64c62'
  return '#66758c'
}

const tableColumns: QTableColumn[] = [
  { name: 'id', label: 'Order ID', field: 'id', align: 'left', sortable: false },
  { name: 'recipient', label: 'Recipient', field: 'shipping_name', align: 'left', sortable: false },
  { name: 'status', label: 'Status', field: 'status', align: 'left', sortable: false },
]
</script>

<style scoped>
.orders-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.9);
  backdrop-filter: blur(6px);
}

.empty-state-card {
  border-radius: 16px;
  border: 1px dashed rgba(0, 0, 0, 0.12);
  background: #fdfdfd;
}

.orders-table-card {
  background: rgba(255, 255, 255, 0.9);
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 14px;
  overflow: hidden;
  backdrop-filter: blur(6px);
}

.orders-table :deep(th) {
  background: rgba(248, 250, 252, 0.96);
  font-size: 0.74rem;
  font-weight: 600;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: #6b7280;
}

.order-row {
  transition: background-color 0.14s ease;
}

.order-row:hover {
  background: rgba(37, 99, 235, 0.03);
}

.costing-file-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  text-transform: capitalize;
}

.status-chip-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

@media (max-width: 599px) {
  .orders-header {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
