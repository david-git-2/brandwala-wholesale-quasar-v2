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
            <q-td key="date" :props="sp">
              {{ formatDate(sp.row.created_at) }}
            </q-td>
            <q-td key="status" :props="sp">
              <q-chip :color="getStatusColor(sp.row.status)" text-color="white" dense square class="text-uppercase text-weight-bold">
                {{ sp.row.status }}
              </q-chip>
            </q-td>
            <q-td key="recipient" :props="sp">
              <div class="text-weight-medium">{{ sp.row.shipping_name || '—' }}</div>
              <div class="text-caption text-grey-6">{{ sp.row.shipping_phone || '—' }}</div>
            </q-td>
            <q-td key="district" :props="sp">
              {{ sp.row.shipping_district || '—' }}
            </q-td>
            <q-td key="items" :props="sp">
              {{ sp.row.item_count }}
            </q-td>
            <q-td key="subtotal" :props="sp" class="text-weight-bold text-grey-9">
              ৳{{ Number(sp.row.subtotal_gbp || 0).toFixed(2) }}
            </q-td>
            <q-td key="commission" :props="sp" class="text-weight-bold text-positive">
              ৳{{ Number(sp.row.total_commission || 0).toFixed(2) }}
            </q-td>
          </q-tr>
        </template>
      </q-table>
    </q-card>

    <!-- Details Dialog -->
    <KobaOrderDetailDialog
      v-model="detailOpen"
      :order="store.orderDetail?.order || null"
      :items="store.orderDetail?.items || []"
      :loading="store.loading"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { date } from 'quasar'
import type { QTableColumn } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useKobaOrderStore } from 'src/modules/koba/retail/stores/kobaOrderStore'
import type { KobaOrderStatus } from 'src/modules/koba/retail/repositories/kobaOrderRepository'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import KobaOrderDetailDialog from 'src/modules/koba/retail/components/KobaOrderDetailDialog.vue'
import FilterSidebar from 'src/components/FilterSidebar.vue'

const authStore = useAuthStore()
const store = useKobaOrderStore()

const productsRouteName = computed(() => {
  return authStore.scope === 'shop' ? 'shop-koba-retail-page' : 'app-koba-retail-page'
})

const filterStatus = ref<KobaOrderStatus | null>(null)
const detailOpen = ref(false)
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

async function viewOrderDetails(orderId: number) {
  detailOpen.value = true
  await store.fetchOrderDetails(orderId)
}

function formatDate(isoString: string) {
  return date.formatDate(new Date(isoString), 'YYYY-MM-DD HH:mm')
}

function getStatusColor(status: string) {
  switch (status) {
    case 'pending': return 'amber-8'
    case 'confirmed': return 'blue-7'
    case 'processing': return 'indigo-7'
    case 'shipped': return 'deep-purple-7'
    case 'delivered': return 'positive'
    case 'cancelled': return 'negative'
    default: return 'grey'
  }
}

const tableColumns: QTableColumn[] = [
  { name: 'id', label: 'Order ID', field: 'id', align: 'left', sortable: false },
  { name: 'date', label: 'Date', field: 'created_at', align: 'left', sortable: false },
  { name: 'status', label: 'Status', field: 'status', align: 'left', sortable: false },
  { name: 'recipient', label: 'Recipient', field: 'shipping_name', align: 'left', sortable: false },
  { name: 'district', label: 'District', field: 'shipping_district', align: 'left', sortable: false },
  { name: 'items', label: 'Items', field: 'item_count', align: 'right', sortable: false },
  { name: 'subtotal', label: 'Subtotal', field: 'subtotal_gbp', align: 'right', sortable: false },
  { name: 'commission', label: 'Commission', field: 'total_commission', align: 'right', sortable: false },
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

@media (max-width: 599px) {
  .orders-header {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
