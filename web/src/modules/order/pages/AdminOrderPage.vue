<template>
  <q-page class="q-pa-md order-list-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Orders</div>
            <div class="text-caption text-grey-8">Manage and open order details</div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-card v-if="storeOptions.length" flat class="q-mb-md floating-surface shadow-1">
      <q-card-section class="q-py-sm">
        <q-btn-toggle
          v-model="selectedStoreId"
          no-caps
          unelevated
          toggle-color="primary"
          color="white"
          text-color="primary"
          :options="storeOptions"
          @update:model-value="onStoreChange"
        />
      </q-card-section>
    </q-card>

    <PageInitialLoader v-if="orderStore.loading" />

    <div v-else>
      <div class="row items-center justify-between q-mb-sm">
        <div class="row items-center q-gutter-sm toolbar-left">
          <q-btn
            v-if="!showSearchInput"
            flat
            round
            dense
            icon="search"
            aria-label="Show search"
            @click="showSearchInput = true"
          />
          <q-input
            v-else
            v-model="searchText"
            outlined
            dense
            class="soft-input toolbar-search"
            label="Search"
            clearable
            autofocus
            @clear="onApplyFilters"
          >
            <template #prepend>
              <q-icon name="search" />
            </template>
            <template #append>
              <q-btn flat round dense icon="close" aria-label="Hide search" @click="onCloseSearch" />
            </template>
          </q-input>
          <q-btn flat round dense icon="filter_alt" aria-label="Filters" @click="openFilterDrawer">
            <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
              {{ activeFilterCount }}
            </q-badge>
          </q-btn>
        </div>

        <q-btn-toggle
          v-model="viewMode"
          dense
          unelevated
          no-caps
          toggle-color="primary"
          color="white"
          text-color="primary"
          :options="[
            { icon: 'table_rows', value: 'table' },
            { icon: 'grid_view', value: 'card' },
          ]"
        />
      </div>

      <q-banner v-if="!filteredOrders.length" class="bg-grey-2 text-grey-8">
        No orders found.
      </q-banner>

      <q-card v-else-if="viewMode === 'table'" flat class="floating-surface shadow-1">
        <q-table
          flat
          :rows="pagedTableOrders"
          :columns="tableColumns"
          row-key="id"
          :pagination="tablePagination"
          class="order-list-table"
        >
          <template #body="slotProps">
            <q-tr
              :props="slotProps"
              class="cursor-pointer"
              :style="statusSurfaceStyle(slotProps.row.status, slotProps.row.accent_color)"
              @click="goToOrder(slotProps.row.id)"
            >
              <q-td key="accent" :props="slotProps" class="order-accent-col">
                <span
                  class="order-accent-pill"
                  :style="{ backgroundColor: slotProps.row.accent_color || '#8ea0b8' }"
                />
              </q-td>
              <q-td key="id" :props="slotProps">#{{ slotProps.row.id }}</q-td>
              <q-td key="name" :props="slotProps">{{ slotProps.row.name }}</q-td>
              <q-td key="customer_group_name" :props="slotProps">{{ slotProps.row.customer_group_name || 'N/A' }}</q-td>
              <q-td key="status" :props="slotProps">
                <q-chip dense square :style="statusChipStyle(slotProps.row.status)" class="order-status-chip">
                  <span class="status-dot" :style="{ backgroundColor: statusDotColor(slotProps.row.status) }" />
                  {{ formatStatus(slotProps.row.status) }}
                </q-chip>
              </q-td>
              <q-td key="actions" :props="slotProps" class="text-right">
                <q-btn
                  v-if="authStore.matchedRole === 'admin'"
                  flat
                  round
                  dense
                  icon="more_vert"
                  :loading="orderStore.saving"
                  @click.stop
                >
                  <q-menu auto-close>
                    <q-list dense style="min-width: 120px">
                      <q-item clickable v-ripple @click="onAskDelete(slotProps.row.id)">
                        <q-item-section class="text-negative">Delete</q-item-section>
                      </q-item>
                    </q-list>
                  </q-menu>
                </q-btn>
              </q-td>
            </q-tr>
          </template>
        </q-table>
      </q-card>

      <div v-else class="order-grid">
        <q-card
          v-for="order in pagedCardOrders"
          :key="order.id"
          class="order-card floating-surface shadow-1"
          flat
          clickable
          :style="statusSurfaceStyle(order.status, order.accent_color)"
          @click="goToOrder(order.id)"
        >
          <q-card-section>
            <div class="row items-center justify-end q-gutter-sm">
              <q-chip dense square :style="statusChipStyle(order.status)" class="order-status-chip">
                <span class="status-dot" :style="{ backgroundColor: statusDotColor(order.status) }" />
                {{ formatStatus(order.status) }}
              </q-chip>
              <q-btn
                v-if="authStore.matchedRole === 'admin'"
                dense
                flat
                round
                icon="more_vert"
                :loading="orderStore.saving"
                @click.stop
              >
                <q-menu auto-close>
                  <q-list dense style="min-width: 120px">
                    <q-item clickable v-ripple @click="onAskDelete(order.id)">
                      <q-item-section class="text-negative">Delete</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </div>

            <div class="row items-center justify-start q-gutter-sm">
              <div class="text-subtitle1 text-weight-medium">#{{ order.id }} {{ order.name }}</div>
            </div>
            <div class="text-caption text-grey-7 q-mt-xs">
              Customer Group: {{ order.customer_group_name || 'N/A' }}
            </div>
          </q-card-section>
        </q-card>
      </div>

      <div v-if="totalPages > 1" class="row justify-center q-mt-md">
        <q-pagination v-model="page" :max="totalPages" :max-pages="8" boundary-numbers direction-links @update:model-value="onPageChange" />
      </div>
    </div>

    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <q-select
        v-model="draftStatusFilter"
        :options="statusFilterOptions"
        outlined
        dense
        class="soft-input q-mb-md"
        emit-value
        map-options
        label="Status"
        @update:model-value="onDrawerStatusChange"
      />
      <div class="row q-gutter-sm justify-end">
        <q-btn flat no-caps label="Reset" @click="onResetFilters" />
      </div>
    </FilterSidebar>

    <q-dialog v-model="confirmDeleteOpen">
      <q-card style="min-width: 320px">
        <q-card-section class="text-h6">Delete Order</q-card-section>
        <q-card-section>
          Are you sure you want to delete this order? This will remove all order items too.
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            label="Delete"
            :loading="orderStore.saving"
            @click="onConfirmDelete"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import type { QTableColumn } from 'quasar'

import { formatStatus } from 'src/composables/useFormatStatus'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useStoreStore } from 'src/modules/store/stores/storeStore'
import { useOrderStore } from '../stores/orderStore'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import FilterSidebar from 'src/components/FilterSidebar.vue'

const authStore = useAuthStore()
const orderStore = useOrderStore()
const storeStore = useStoreStore()
const router = useRouter()
const page = ref(1)
const viewMode = ref<'table' | 'card'>('table')
const showSearchInput = ref(false)
const searchText = ref('')
const statusFilter = ref<string>('__all__')
const draftStatusFilter = ref<string>('__all__')
const filterDrawerOpen = ref(false)
const confirmDeleteOpen = ref(false)
const pendingDeleteOrderId = ref<number | null>(null)
const tablePagination = ref({
  page: 1,
  rowsPerPage: 20,
})

const tableColumns: QTableColumn[] = [
  { name: 'accent', label: '', field: 'accent', align: 'left' },
  { name: 'id', label: 'ID', field: 'id', align: 'left' },
  { name: 'name', label: 'Name', field: 'name', align: 'left' },
  { name: 'customer_group_name', label: 'Customer Group', field: 'customer_group_name', align: 'left' },
  { name: 'status', label: 'Status', field: 'status', align: 'left' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'right' },
]

const statusFilterOptions = [
  { label: 'All', value: '__all__' },
  { label: 'Customer Submit', value: 'customer_submit' },
  { label: 'Direct Priced', value: 'direct_priced' },
  { label: 'Priced', value: 'priced' },
  { label: 'Negotiate', value: 'negotiate' },
  { label: 'Final Offered', value: 'final_offered' },
  { label: 'Ordered', value: 'ordered' },
  { label: 'Order Placed', value: 'order_placed' },
  { label: 'Processing', value: 'processing' },
  { label: 'Invoicing', value: 'invoicing' },
  { label: 'Invoiced', value: 'invoiced' },
]

const activeFilterCount = computed(() => (statusFilter.value !== '__all__' ? 1 : 0))

const filteredOrders = computed(() => {
  const search = searchText.value.trim().toLowerCase()
  return orderStore.items.filter((order) => {
    const matchSearch =
      search.length === 0 ||
      String(order.id).includes(search) ||
      String(order.name ?? '').toLowerCase().includes(search) ||
      String(order.customer_group_name ?? '').toLowerCase().includes(search)
    const matchStatus = statusFilter.value === '__all__' || order.status === statusFilter.value
    return matchSearch && matchStatus
  })
})

const totalPages = computed(() => Math.max(1, Math.ceil(filteredOrders.value.length / tablePagination.value.rowsPerPage)))
const pagedTableOrders = computed(() => {
  const start = (page.value - 1) * tablePagination.value.rowsPerPage
  return filteredOrders.value.slice(start, start + tablePagination.value.rowsPerPage)
})
const pagedCardOrders = computed(() => pagedTableOrders.value)

const selectedStoreId = computed<number | null>({
  get: () => storeStore.selectedStore?.id ?? null,
  set: (value) => {
    storeStore.setSelectedStoreById(value)
  },
})

const storeOptions = computed(() =>
  storeStore.items.map((store) => ({
    label: store.name,
    value: store.id,
  })),
)

const loadOrders = async (nextPage = 1) => {
  const tenantId = authStore.tenantId
  await orderStore.fetchOrders({
    tenant_id: tenantId ?? null,
    store_id: storeStore.selectedStore?.id ?? null,
    page: 1,
    page_size: 20,
  })
  page.value = nextPage
}

onMounted(async () => {
  const tenantId = authStore.tenantId
  if (tenantId) {
    await storeStore.fetchStoresAdmin(tenantId)
    if (!storeStore.selectedStore || !storeStore.items.some((item) => item.id === storeStore.selectedStore?.id)) {
      storeStore.setSelectedStore(storeStore.items[0] ?? null)
    }
  }
  await loadOrders(1)
})

const deleteOrder = async (id: number) => {
  await orderStore.deleteOrder({ id, tenant_id: authStore.tenantId ?? null })
  await loadOrders(page.value)
}

const onAskDelete = (id: number) => {
  pendingDeleteOrderId.value = id
  confirmDeleteOpen.value = true
}

const onConfirmDelete = async () => {
  if (!pendingDeleteOrderId.value) {
    return
  }

  await deleteOrder(pendingDeleteOrderId.value)
  pendingDeleteOrderId.value = null
  confirmDeleteOpen.value = false
}

const onPageChange = (nextPage: number) => {
  page.value = nextPage
}

const onStoreChange = async () => {
  page.value = 1
  await loadOrders(1)
}

const onApplyFilters = () => {
  page.value = 1
}

const onCloseSearch = () => {
  searchText.value = ''
  showSearchInput.value = false
  onApplyFilters()
}

const openFilterDrawer = () => {
  draftStatusFilter.value = statusFilter.value
  filterDrawerOpen.value = true
}

const onDrawerStatusChange = () => {
  statusFilter.value = draftStatusFilter.value
  page.value = 1
}

const onResetFilters = () => {
  searchText.value = ''
  statusFilter.value = '__all__'
  draftStatusFilter.value = '__all__'
  page.value = 1
  filterDrawerOpen.value = false
}

const statusSurfaceStyle = (status: string | null | undefined, accentColor: string | null | undefined) => {
  const value = (status ?? '').toLowerCase()
  const accentFallback =
    value === 'customer_submit' ? '#d8a54a' :
    value === 'direct_priced' ? '#5779bd' :
    value === 'priced' ? '#5cbfd6' :
    value === 'negotiate' ? '#df7f63' :
    value === 'final_offered' ? '#9a74d4' :
    value === 'ordered' ? '#5b82d6' :
    value === 'order_placed' ? '#5b82d6' :
    value === 'processing' ? '#59aa7d' :
    value === 'invoicing' ? '#df9549' :
    value === 'invoiced' ? '#449a69' :
    '#8ea0b8'
  const leftAccent = accentColor || accentFallback
  if (value === 'customer_submit') return { backgroundColor: '#fffbf2', borderLeft: `6px solid ${leftAccent}` }
  if (value === 'direct_priced') return { backgroundColor: '#eef4ff', borderLeft: `6px solid ${leftAccent}` }
  if (value === 'priced') return { backgroundColor: '#eefbff', borderLeft: `6px solid ${leftAccent}` }
  if (value === 'negotiate') return { backgroundColor: '#fff3ef', borderLeft: `6px solid ${leftAccent}` }
  if (value === 'final_offered') return { backgroundColor: '#f8f4ff', borderLeft: `6px solid ${leftAccent}` }
  if (value === 'ordered') return { backgroundColor: '#eef4ff', borderLeft: `6px solid ${leftAccent}` }
  if (value === 'order_placed') return { backgroundColor: '#eef4ff', borderLeft: `6px solid ${leftAccent}` }
  if (value === 'processing') return { backgroundColor: '#f2fbf6', borderLeft: `6px solid ${leftAccent}` }
  if (value === 'invoicing') return { backgroundColor: '#fff7ee', borderLeft: `6px solid ${leftAccent}` }
  if (value === 'invoiced') return { backgroundColor: '#edf9f2', borderLeft: `6px solid ${leftAccent}` }
  return { backgroundColor: '#f8f9fb', borderLeft: `6px solid ${leftAccent}` }
}

const statusChipStyle = (status: string | null | undefined) => {
  const value = (status ?? '').toLowerCase()
  if (value === 'customer_submit') return { backgroundColor: '#efd399', color: '#6a4a14', border: '1px solid #d8b672' }
  if (value === 'direct_priced') return { backgroundColor: '#d8e4ff', color: '#2b4b85', border: '1px solid #bdd0f7' }
  if (value === 'priced') return { backgroundColor: '#bde9f4', color: '#1e5f71', border: '1px solid #9fd8e7' }
  if (value === 'negotiate') return { backgroundColor: '#f4c8ba', color: '#7f3420', border: '1px solid #e7ab98' }
  if (value === 'final_offered') return { backgroundColor: '#dccdfa', color: '#4e2d86', border: '1px solid #c6b1f1' }
  if (value === 'ordered') return { backgroundColor: '#c4d5fa', color: '#274a8d', border: '1px solid #a9c2f2' }
  if (value === 'order_placed') return { backgroundColor: '#c4d5fa', color: '#274a8d', border: '1px solid #a9c2f2' }
  if (value === 'processing') return { backgroundColor: '#c3e8d2', color: '#1f5d3c', border: '1px solid #9fd4b7' }
  if (value === 'invoicing') return { backgroundColor: '#f7d6af', color: '#7a4516', border: '1px solid #ecc08f' }
  if (value === 'invoiced') return { backgroundColor: '#b9e3ca', color: '#194f35', border: '1px solid #95cfaf' }
  return { backgroundColor: '#dbe5f3', color: '#3b4b66', border: '1px solid #b9c8dd' }
}

const statusDotColor = (status: string | null | undefined) => {
  const value = (status ?? '').toLowerCase()
  if (value === 'customer_submit') return '#9a6a24'
  if (value === 'direct_priced') return '#3d5f9e'
  if (value === 'priced') return '#308ca6'
  if (value === 'negotiate') return '#b65336'
  if (value === 'final_offered') return '#6f4ab2'
  if (value === 'ordered') return '#3f67b3'
  if (value === 'order_placed') return '#3f67b3'
  if (value === 'processing') return '#2f8b5d'
  if (value === 'invoicing') return '#b86d23'
  if (value === 'invoiced') return '#25784d'
  return '#66758c'
}

const goToOrder = async (id: number) => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/orders/${id}`)
}
</script>

<style scoped>
.order-list-page {
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

.order-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.order-card {
  border-radius: 10px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.order-list-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}

.order-accent-col {
  width: 22px;
}

.order-accent-pill {
  display: inline-block;
  width: 10px;
  height: 30px;
  border-radius: 999px;
}

.order-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.toolbar-left {
  min-width: 0;
}

.toolbar-search {
  width: min(320px, 75vw);
}

@media (max-width: 700px) {
  .order-grid {
    grid-template-columns: 1fr;
  }
}
</style>
