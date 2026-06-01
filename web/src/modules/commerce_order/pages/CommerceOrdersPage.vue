<template>
  <q-page class="q-pa-md commerce-orders-list-page">
    <!-- Hero / Header Card -->
    <q-card flat class="hero-surface floating-surface shadow-1 q-mb-md q-pa-md">
      <div class="row items-center justify-between">
        <div>
          <div class="text-h6 text-weight-bold text-primary">Commerce Orders</div>
          <div class="text-caption text-grey-8">Manage customer commerce orders, update status, and generate invoices.</div>
        </div>
      </div>
    </q-card>

    <!-- Loading State -->
    <div v-if="loading" class="row justify-center q-my-xl">
      <q-spinner-dots size="40px" color="primary" />
    </div>

    <!-- Empty State -->
    <div v-else-if="!orders.length" class="column items-center justify-center q-pa-xl empty-state-block floating-surface shadow-1">
      <q-icon name="receipt_long" size="64px" class="q-mb-sm text-grey-4" />
      <div class="text-subtitle1 text-weight-medium text-grey-7">No Commerce Orders Found</div>
      <div class="text-caption text-grey-5">Commerce orders will appear here once placed by customers.</div>
    </div>

    <!-- Orders Table -->
    <q-card v-else flat class="floating-surface shadow-1">
      <q-table
        flat
        :rows="orders"
        :columns="columns"
        row-key="id"
        class="orders-table"
        :rows-per-page-options="[10, 20, 50]"
        @row-click="onRowClick"
      >
        <!-- Status Column -->
        <template #body-cell-status="props">
          <q-td :props="props">
            <q-chip
              square
              dense
              :color="getStatusColor(props.value)"
              text-color="white"
              class="text-weight-bold status-chip"
            >
              <span class="status-chip-dot" :style="{ backgroundColor: getStatusDotColor(props.value) }"></span>
              {{ props.value.toUpperCase() }}
            </q-chip>
          </q-td>
        </template>

        <!-- Placed Date Column -->
        <template #body-cell-order_placement_date="props">
          <q-td :props="props">
            {{ formatDate(props.value) }}
          </q-td>
        </template>

        <!-- Grand Total Column -->
        <template #body-cell-shipment_payment="props">
          <q-td :props="props" class="text-weight-bold text-primary">
            ৳{{ Number(props.value || 0).toFixed(2) }}
          </q-td>
        </template>
      </q-table>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import type { QTableColumn } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { commerceOrderService } from '../services/commerceOrderService'
import type { CommerceOrder, CommerceOrderStatus } from '../types'

const authStore = useAuthStore()
const router = useRouter()

// State
const loading = ref(true)
const orders = ref<CommerceOrder[]>([])

const columns: QTableColumn[] = [
  { name: 'id', label: 'Order ID', field: 'id', align: 'left', sortable: true },
  { name: 'order_placement_date', label: 'Placed Date', field: 'order_placement_date', align: 'left', sortable: true },
  { name: 'recipient_name', label: 'Recipient Name', field: 'recipient_name', align: 'left', sortable: true },
  { name: 'recipient_phone', label: 'Recipient Phone', field: 'recipient_phone', align: 'left' },
  { name: 'shipment_payment', label: 'Grand Total', field: 'shipment_payment', align: 'right', sortable: true },
  { name: 'status', label: 'Status', field: 'status', align: 'center', sortable: true },
]

const loadOrders = async () => {
  if (!authStore.tenantId) return
  loading.value = true
  try {
    const res = await commerceOrderService.listCommerceOrders(authStore.tenantId)
    if (res.success && res.data) {
      orders.value = res.data
    } else {
      orders.value = []
    }
  } finally {
    loading.value = false
  }
}

const onRowClick = (_evt: Event, row: CommerceOrder) => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  void router.push(`${tenantPrefix}/app/commerce-shop/orders/${row.id}`)
}

const getStatusColor = (status: CommerceOrderStatus) => {
  switch (status) {
    case 'placed': return 'blue-2'
    case 'reviewing': return 'orange-2'
    case 'shipping': return 'purple-2'
    case 'delivered': return 'green-2'
    case 'cancelled': return 'red-2'
    default: return 'grey-2'
  }
}

const getStatusDotColor = (status: CommerceOrderStatus) => {
  switch (status) {
    case 'placed': return '#1976d2'
    case 'reviewing': return '#f57c00'
    case 'shipping': return '#7b1fa2'
    case 'delivered': return '#388e3c'
    case 'cancelled': return '#d32f2f'
    default: return '#616161'
  }
}

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleString()
}

onMounted(() => {
  void loadOrders()
})
</script>

<style scoped>
.commerce-orders-list-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.empty-state-block {
  text-align: center;
  background: rgba(255, 255, 255, 0.7);
}

.orders-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
  font-weight: 600;
  color: #2c3e50;
}

.orders-table :deep(tr) {
  cursor: pointer;
  transition: background-color 0.2s ease;
}

.orders-table :deep(tr:hover) {
  background-color: rgba(34, 56, 101, 0.03);
}

.status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  color: #2c3e50 !important;
}

.status-chip-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}
</style>
