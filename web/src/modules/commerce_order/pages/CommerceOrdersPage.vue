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
    <PageInitialLoader v-if="loading" />

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
        :loading="loading"
        :pagination="tablePagination"
        :rows-per-page-options="[10, 20, 50]"
        @request="onTableRequest"
      >
        <template #body="slotProps">
          <q-tr
            :props="slotProps"
            class="cursor-pointer"
            :style="statusSurfaceStyle(slotProps.row.status)"
            @click="onRowClick(slotProps.row)"
          >
            <!-- ID Column -->
            <q-td key="id" :props="slotProps">
              #{{ slotProps.row.id }}
            </q-td>

            <!-- Customer Name Column -->
            <q-td key="customer_name" :props="slotProps">
              {{ slotProps.row.customer_group_name || slotProps.row.recipient_name || '-' }}
            </q-td>

            <!-- Phone Column -->
            <q-td key="recipient_phone" :props="slotProps">
              {{ slotProps.row.recipient_phone || '-' }}
            </q-td>

            <!-- Status Column -->
            <q-td key="status" :props="slotProps" class="text-center">
              <q-chip
                square
                dense
                clickable
                :style="statusChipStyle(slotProps.row.status)"
                class="status-chip"
                @click.stop
              >
                <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(slotProps.row.status) }"></span>
                {{ slotProps.row.status.toUpperCase() }}
                <q-menu auto-close>
                  <q-list dense style="min-width: 120px">
                    <q-item
                      v-for="opt in statusOptions"
                      :key="opt"
                      clickable
                      v-close-popup
                      @click="onStatusMenuSelect(slotProps.row.id, opt)"
                    >
                      <q-item-section>{{ opt.toUpperCase() }}</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-chip>
            </q-td>
          </q-tr>
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
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback'

const authStore = useAuthStore()
const router = useRouter()

// State
const loading = ref(true)
const orders = ref<CommerceOrder[]>([])
const page = ref(1)
const rowsPerPage = ref(10)

const tablePagination = ref({
  page: 1,
  rowsPerPage: 10,
  rowsNumber: 0,
})

const columns: QTableColumn[] = [
  { name: 'id', label: 'Order ID', field: 'id', align: 'left' },
  { name: 'customer_name', label: 'Customer Name', field: 'customer_group_name', align: 'left' },
  { name: 'recipient_phone', label: 'Phone', field: 'recipient_phone', align: 'left' },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
]

const statusOptions: CommerceOrderStatus[] = ['placed', 'reviewing', 'shipping', 'delivered', 'cancelled']

const loadOrders = async () => {
  if (!authStore.tenantId) return
  loading.value = true
  try {
    const res = await commerceOrderService.listCommerceOrders(authStore.tenantId, {
      page: page.value,
      page_size: rowsPerPage.value,
    })
    if (res.success && res.data) {
      orders.value = res.data.data
      tablePagination.value = {
        page: res.data.meta.page,
        rowsPerPage: res.data.meta.page_size,
        rowsNumber: res.data.meta.total,
      }
    } else {
      orders.value = []
    }
  } finally {
    loading.value = false
  }
}

const onTableRequest = async (payload: {
  pagination: { page: number; rowsPerPage: number; rowsNumber?: number }
}) => {
  page.value = payload.pagination.page
  rowsPerPage.value = payload.pagination.rowsPerPage
  await loadOrders()
}

const onRowClick = (row: CommerceOrder) => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  void router.push(`${tenantPrefix}/app/commerce-shop/orders/${row.id}`)
}

const onStatusMenuSelect = async (orderId: number, nextStatus: CommerceOrderStatus) => {
  loading.value = true
  try {
    const res = await commerceOrderService.updateCommerceOrderStatus(orderId, nextStatus)
    if (res.success) {
      showSuccessNotification('Order status updated successfully.')
      await loadOrders()
    } else {
      showWarningDialog(res.error || 'Failed to update order status.')
    }
  } finally {
    loading.value = false
  }
}

const statusSurfaceStyle = (status: CommerceOrderStatus) => {
  switch (status) {
    case 'placed':
      return {
        backgroundColor: '#f3f7ff',
        boxShadow: 'inset 6px 0 0 #6f93d8',
      }
    case 'reviewing':
      return {
        backgroundColor: '#fffbf2',
        boxShadow: 'inset 6px 0 0 #d8a54a',
      }
    case 'shipping':
      return {
        backgroundColor: '#faf5ff',
        boxShadow: 'inset 6px 0 0 #a25ddc',
      }
    case 'delivered':
      return {
        backgroundColor: '#f2fbf6',
        boxShadow: 'inset 6px 0 0 #59aa7d',
      }
    case 'cancelled':
      return {
        backgroundColor: '#fff4f6',
        boxShadow: 'inset 6px 0 0 #c97586',
      }
    default:
      return {
        backgroundColor: '#f8f9fb',
        boxShadow: 'inset 6px 0 0 #8ea0b8',
      }
  }
}

const statusChipStyle = (status: CommerceOrderStatus) => {
  switch (status) {
    case 'placed':
      return {
        backgroundColor: '#c8d8f8',
        color: '#27487a',
        border: '1px solid #a9c4f3',
        boxShadow: '0 1px 2px rgba(39, 72, 122, 0.18)',
      }
    case 'reviewing':
      return {
        backgroundColor: '#efd399',
        color: '#6a4a14',
        border: '1px solid #d8b672',
        boxShadow: '0 1px 2px rgba(106, 74, 20, 0.18)',
      }
    case 'shipping':
      return {
        backgroundColor: '#ecd9fc',
        color: '#5b1f9c',
        border: '1px solid #d9b8fa',
        boxShadow: '0 1px 2px rgba(91, 31, 156, 0.18)',
      }
    case 'delivered':
      return {
        backgroundColor: '#c3e8d2',
        color: '#1f5d3c',
        border: '1px solid #9fd4b7',
        boxShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
      }
    case 'cancelled':
      return {
        backgroundColor: '#f2c7d0',
        color: '#6f2b3a',
        border: '1px solid #e3a6b3',
        boxShadow: '0 1px 2px rgba(111, 43, 58, 0.18)',
      }
    default:
      return {
        backgroundColor: '#dbe5f3',
        color: '#3b4b66',
        border: '1px solid #b9c8dd',
        boxShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
      }
  }
}

const statusDotColor = (status: CommerceOrderStatus) => {
  switch (status) {
    case 'placed': return '#3f67b3'
    case 'reviewing': return '#9a6a24'
    case 'shipping': return '#7b1fa2'
    case 'delivered': return '#2f8b5d'
    case 'cancelled': return '#a64c62'
    default: return '#66758c'
  }
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
