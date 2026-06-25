<template>
  <q-page class="bw-page">
    <div class="bw-page__stack">
      <!-- Page Header -->
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col">
          <AppPageHeader
            eyebrow="Procurement & Stock"
            title="Allocate Stock"
            subtitle="Distribute physical stock pools to sister concerns (child tenants)"
          />
        </div>
        <div class="col-auto">
          <q-btn
            flat
            color="primary"
            icon="arrow_back"
            label="Back to Stock"
            no-caps
            @click="goBack"
          />
        </div>
      </div>

      <!-- Parent Context Validation Banner -->
      <q-banner v-if="!isParentContext" class="bg-orange-1 text-orange-10 rounded-borders q-mb-md bw-status-banner">
        <template #avatar>
          <q-icon name="warning" color="warning" />
        </template>
        Allocate Stock is restricted to parent tenant administrators. Please switch to the parent tenant context.
      </q-banner>

      <!-- Main Content (Only visible for Parent Context) -->
      <template v-else>
        <!-- Search and Filter Toolbar -->
        <div class="row items-center q-gutter-sm q-mb-md">
          <q-input
            v-model="searchText"
            filled
            dense
            clearable
            class="col-grow"
            label="Search ready stock pools..."
            @keyup.enter="onSearch"
            @clear="onSearch"
          >
            <template #prepend>
              <q-icon name="search" />
            </template>
          </q-input>

          <q-btn flat round dense icon="filter_alt" @click="openFilterDrawer">
            <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
              {{ activeFilterCount }}
            </q-badge>
          </q-btn>
        </div>

        <!-- Filter Sidebar -->
        <FilterSidebar v-model="filterDrawerOpen" title="Filters">
          <div class="q-gutter-y-md q-pa-sm">
            <q-select
              v-model="draftShipmentFilter"
              :options="shipmentOptions"
              label="Shipment Batch"
              filled
              dense
              clearable
              emit-value
              map-options
            />

            <q-select
              v-model="draftStockTypeFilter"
              :options="stockTypeOptions"
              label="Stock Type"
              filled
              dense
              clearable
              emit-value
              map-options
            />

            <div class="row justify-end q-gutter-x-sm q-mt-md">
              <q-btn flat no-caps label="Reset" color="grey-7" @click="onResetFilters" />
              <q-btn unelevated no-caps label="Apply Filters" color="primary" @click="onApplyDrawerFilters" />
            </div>
          </div>
        </FilterSidebar>

        <!-- Allocatable Stock Pools Table -->
        <q-card flat bordered class="q-pa-none">
          <q-table
            flat
            :rows="allocationStore.allocatableStocks"
            :columns="columns"
            row-key="id"
            :loading="allocationStore.loadingAllocatable"
            v-model:pagination="pagination"
            @request="onRequest"
            binary-state-sort
          >
            <!-- Product Column -->
            <template #body-cell-product="props">
              <q-td :props="props">
                <div class="row items-center q-gutter-x-sm no-wrap">
                  <q-avatar rounded size="40px" class="bg-grey-2">
                    <img v-if="props.row.image_url" :src="props.row.image_url" alt="Product" style="object-fit: cover;" />
                    <q-icon v-else name="inventory_2" color="grey-6" size="24px" />
                  </q-avatar>
                  <div>
                    <div class="text-weight-bold text-grey-9">{{ props.row.item_name }}</div>
                    <div class="text-caption text-grey-6 row q-gutter-x-sm">
                      <span v-if="props.row.product_code">Code: {{ props.row.product_code }}</span>
                      <span v-if="props.row.barcode">Barcode: {{ props.row.barcode }}</span>
                    </div>
                  </div>
                </div>
              </q-td>
            </template>

            <!-- Actions Column -->
            <template #body-cell-actions="props">
              <q-td :props="props" align="center">
                <q-btn
                  flat
                  no-caps
                  dense
                  color="primary"
                  :icon="isExpanded(props.row.id) ? 'keyboard_arrow_up' : 'keyboard_arrow_down'"
                  :label="isExpanded(props.row.id) ? 'Collapse' : 'Manage Allocations'"
                  @click="toggleRowExpansion(props.row)"
                />
              </q-td>
            </template>

            <!-- Expanded Row Slot -->
            <template #body="props">
              <q-tr :props="props">
                <q-td v-for="col in props.cols" :key="col.name" :props="props">
                  <template v-if="col.name === 'product'">
                    <div class="row items-center q-gutter-x-sm no-wrap">
                      <q-avatar rounded size="40px" class="bg-grey-2">
                        <img v-if="props.row.image_url" :src="props.row.image_url" alt="Product" style="object-fit: cover;" />
                        <q-icon v-else name="inventory_2" color="grey-6" size="24px" />
                      </q-avatar>
                      <div>
                        <div class="text-weight-bold text-grey-9">{{ props.row.item_name }}</div>
                        <div class="text-caption text-grey-6 row q-gutter-x-sm">
                          <span v-if="props.row.product_code">Code: {{ props.row.product_code }}</span>
                          <span v-if="props.row.barcode">Barcode: {{ props.row.barcode }}</span>
                        </div>
                      </div>
                    </div>
                  </template>
                  <template v-else-if="col.name === 'actions'">
                    <q-btn
                      flat
                      no-caps
                      dense
                      color="primary"
                      :icon="isExpanded(props.row.id) ? 'keyboard_arrow_up' : 'keyboard_arrow_down'"
                      :label="isExpanded(props.row.id) ? 'Collapse' : 'Manage Allocations'"
                      @click="toggleRowExpansion(props.row)"
                    />
                  </template>
                  <template v-else>
                    {{ col.value }}
                  </template>
                </q-td>
              </q-tr>
              
              <!-- Expanded content details -->
              <q-tr v-if="isExpanded(props.row.id)" :props="props" class="bg-grey-1">
                <q-td colspan="100%">
                  <div class="q-pa-md">
                    <div class="text-subtitle2 text-weight-bold text-primary q-mb-sm">
                      Child Tenant Allocations for {{ props.row.item_name }}
                    </div>

                    <div v-if="rowLoadingState[props.row.id]" class="row justify-center q-py-md">
                      <q-spinner color="primary" size="24px" />
                    </div>

                    <div v-else class="column q-gutter-y-sm">
                      <!-- Active allocations per child tenant -->
                      <div class="row q-col-gutter-sm items-center q-pb-xs border-bottom text-caption text-weight-bold text-grey-7">
                        <div class="col-4">Sister Concern</div>
                        <div class="col-4 text-center">Allocated Quantity</div>
                        <div class="col-4 text-right">Actions</div>
                      </div>

                      <div
                        v-for="child in childTenants"
                        :key="child.id"
                        class="row q-col-gutter-sm items-center q-py-sm"
                      >
                        <div class="col-4 text-body2 text-grey-9">{{ child.name }}</div>
                        <div class="col-4 row justify-center">
                          <q-input
                            v-model.number="draftQuantities[props.row.id]![child.id]"
                            type="number"
                            dense
                            filled
                            min="0"
                            class="soft-input text-center"
                            style="max-width: 120px;"
                            input-class="text-center"
                            @update:model-value="onQtyChange(props.row)"
                          />
                        </div>
                        <div class="col-4 row justify-end q-gutter-x-sm">
                          <q-btn
                            unelevated
                            size="sm"
                            color="primary"
                            label="Save"
                            no-caps
                            :loading="submittingMap[`${props.row.id}-${child.id}`]"
                            :disable="isOverAllocated(props.row.id) || !hasQtyChanged(props.row.id, child.id)"
                            @click="saveAllocation(props.row, child.id)"
                          />
                          <q-btn
                            outline
                            size="sm"
                            color="negative"
                            label="Remove"
                            no-caps
                            :loading="submittingMap[`${props.row.id}-${child.id}`]"
                            :disable="!hasExistingAllocation(props.row.id, child.id)"
                            @click="removeAllocation(props.row, child.id)"
                          />
                        </div>
                      </div>

                      <!-- Reconciliation and totals summary -->
                      <div class="row justify-between items-center q-mt-md q-pt-md border-top">
                        <div class="text-caption text-grey-8">
                          Pool Qty: <span class="text-weight-bold">{{ props.row.pool_quantity }}</span> &nbsp;|&nbsp;
                          Allocated Total: <span class="text-weight-bold" :class="isOverAllocated(props.row.id) ? 'text-negative' : 'text-primary'">{{ draftTotals[props.row.id] ?? 0 }}</span> &nbsp;|&nbsp;
                          Remaining: <span class="text-weight-bold">{{ props.row.pool_quantity - (draftTotals[props.row.id] ?? 0) }}</span>
                        </div>
                        <div v-if="isOverAllocated(props.row.id)" class="text-caption text-negative text-weight-bold">
                          <q-icon name="warning" color="negative" /> Allocation exceeds pool capacity! Save disabled.
                        </div>
                      </div>
                    </div>
                  </div>
                </q-td>
              </q-tr>
            </template>

            <!-- Empty State -->
            <template #no-data>
              <div class="full-width text-center text-grey-7 q-py-lg">
                <q-icon name="inventory" size="48px" class="q-mb-sm text-grey-4" />
                <div>No ready stock pools found for allocation. Ensure shipments are received and in Ready Stock.</div>
              </div>
            </template>
          </q-table>
        </q-card>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar, type QTableColumn } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import { useGlobalShipmentStore } from 'src/modules/procurement_stock/stores/globalShipmentStore'
import { useGlobalStockTypeStore } from 'src/modules/procurement_stock/stores/globalStockTypeStore'
import { useGlobalStockAllocationStore } from 'src/modules/procurement_stock/stores/globalStockAllocationStore'
import { globalStockAllocationRepository, type AllocatableStock } from '../repositories/globalStockAllocationRepository'
import AppPageHeader from 'src/components/ui/AppPageHeader.vue'
import FilterSidebar from 'src/components/FilterSidebar.vue'

const router = useRouter()
const $q = useQuasar()
const authStore = useAuthStore()
const tenantStore = useTenantStore()
const shipmentStore = useGlobalShipmentStore()
const stockTypeStore = useGlobalStockTypeStore()
const allocationStore = useGlobalStockAllocationStore()

// State
const searchText = ref('')
const expandedRows = ref<number[]>([])

// Filter State
const filterDrawerOpen = ref(false)
const shipmentFilter = ref<number | null>(null)
const stockTypeFilter = ref<number | null>(null)
const draftShipmentFilter = ref<number | null>(null)
const draftStockTypeFilter = ref<number | null>(null)

// Allocation editing states
const childTenants = ref<{ id: number; name: string }[]>([])
const rowLoadingState = ref<Record<number, boolean>>({})
const savedQuantities = ref<Record<number, Record<number, number>>>({}) // Map of stockId -> childTenantId -> qty
const draftQuantities = ref<Record<number, Record<number, number>>>({}) // Map of stockId -> childTenantId -> qty
const draftTotals = ref<Record<number, number>>({})
const submittingMap = ref<Record<string, boolean>>({})

// Table Pagination
const pagination = ref({
  sortBy: 'id',
  descending: true,
  page: 1,
  rowsPerPage: 20,
  rowsNumber: 0,
})

// Column definitions
const columns: QTableColumn[] = [
  { name: 'product', label: 'Product Details', field: 'item_name', align: 'left', sortable: true },
  { name: 'shipment', label: 'Shipment Batch', field: 'shipment_name', align: 'left', sortable: true },
  { name: 'stock_type', label: 'Stock Type', field: 'stock_type_description', align: 'left', sortable: true },
  { name: 'pool_quantity', label: 'Pool Qty', field: 'pool_quantity', align: 'center', sortable: true },
  { name: 'allocated_qty', label: 'Allocated', field: 'allocated_qty', align: 'center', sortable: true },
  { name: 'unallocated_qty', label: 'Unallocated', field: 'unallocated_qty', align: 'center', sortable: true },
  { name: 'actions', label: 'Actions', field: 'id', align: 'center' },
]

// Computed properties for Context Verification
const contextTenantId = computed(() => tenantStore.selectedTenantId ?? authStore.tenantId ?? null)
const effectiveParentTenantId = computed(() => {
  const current =
    tenantStore.selectedTenant ??
    tenantStore.items.find((tenant) => tenant.id === authStore.tenantId) ??
    null
  if (!current) return authStore.tenantId
  return current.parent_id ?? current.id
})
const isParentContext = computed(() => {
  return (
    contextTenantId.value !== null &&
    effectiveParentTenantId.value !== null &&
    contextTenantId.value === effectiveParentTenantId.value
  )
})

// Active Filter Count
const activeFilterCount = computed(() => {
  let count = 0
  if (shipmentFilter.value !== null) count++
  if (stockTypeFilter.value !== null) count++
  return count
})

// Select options
const shipmentOptions = computed(() => {
  return shipmentStore.rows
    .filter((s) => s.status === 'Ready Stock')
    .map((s) => ({ label: s.name, value: s.id }))
})

const stockTypeOptions = computed(() => {
  return stockTypeStore.items
    .filter((t) => t.is_sellable)
    .map((t) => ({ label: t.description, value: t.id }))
})

// Handlers
const goBack = () => {
  router.back()
}

const isExpanded = (id: number) => {
  return expandedRows.value.includes(id)
}

const toggleRowExpansion = async (row: AllocatableStock) => {
  const index = expandedRows.value.indexOf(row.id)
  if (index > -1) {
    expandedRows.value.splice(index, 1)
  } else {
    expandedRows.value.push(row.id)
    await loadRowAllocations(row.id)
  }
}

// Loads allocations for child tenants of a specific stock pool
const loadRowAllocations = async (stockId: number) => {
  rowLoadingState.value[stockId] = true
  try {
    const data = await globalStockAllocationRepository.listChildAllocationSummary(stockId)
    
    // Initialize maps
    const saved = savedQuantities.value[stockId] ?? {}
    const draft = draftQuantities.value[stockId] ?? {}
    savedQuantities.value[stockId] = saved
    draftQuantities.value[stockId] = draft
    
    // Pre-fill child concerns
    childTenants.value.forEach((child) => {
      const existing = data.find((d) => Number(d.child_tenant_id) === child.id)
      const qty = existing ? existing.allocated_qty : 0
      saved[child.id] = qty
      draft[child.id] = qty
    })
    
    recalculateDraftTotal(stockId)
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    $q.notify({ type: 'negative', message: msg || 'Failed to load allocations.' })
  } finally {
    rowLoadingState.value[stockId] = false
  }
}

const recalculateDraftTotal = (stockId: number) => {
  const stockDrafts = draftQuantities.value[stockId] || {}
  draftTotals.value[stockId] = childTenants.value.reduce((sum, child) => {
    const val = Number(stockDrafts[child.id])
    return sum + (Number.isFinite(val) ? Math.max(0, val) : 0)
  }, 0)
}

const onQtyChange = (row: AllocatableStock) => {
  recalculateDraftTotal(row.id)
}

const isOverAllocated = (stockId: number) => {
  const pool = allocationStore.allocatableStocks.find((s) => s.id === stockId)
  if (!pool) return false
  return (draftTotals.value[stockId] || 0) > pool.pool_quantity
}

const hasQtyChanged = (stockId: number, childId: number) => {
  const saved = savedQuantities.value[stockId]?.[childId] ?? 0
  const draft = draftQuantities.value[stockId]?.[childId] ?? 0
  return saved !== draft
}

const hasExistingAllocation = (stockId: number, childId: number) => {
  const saved = savedQuantities.value[stockId]?.[childId] ?? 0
  return saved > 0
}

const saveAllocation = async (row: AllocatableStock, childId: number) => {
  const stockId = row.id
  const qty = Number(draftQuantities.value[stockId]?.[childId] || 0)
  const key = `${stockId}-${childId}`
  
  submittingMap.value[key] = true
  try {
    await globalStockAllocationRepository.upsertGlobalStockAllocation(
      authStore.tenantId!,
      childId,
      stockId,
      qty
    )
    $q.notify({ type: 'positive', message: 'Allocation updated successfully.' })
    await loadRowAllocations(stockId)
    await fetchAllocatableData()
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    $q.notify({ type: 'negative', message: msg || 'Failed to update allocation.' })
  } finally {
    submittingMap.value[key] = false
  }
}

const removeAllocation = (row: AllocatableStock, childId: number) => {
  const stockId = row.id
  const key = `${stockId}-${childId}`
  
  $q.dialog({
    title: 'Confirm Removal',
    message: 'Are you sure you want to remove this child concern allocation?',
    cancel: true,
    persistent: true,
  }).onOk(() => {
    void (async () => {
      submittingMap.value[key] = true
      try {
        await globalStockAllocationRepository.upsertGlobalStockAllocation(
          authStore.tenantId!,
          childId,
          stockId,
          0
        )
        $q.notify({ type: 'positive', message: 'Allocation removed successfully.' })
        await loadRowAllocations(stockId)
        await fetchAllocatableData()
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err)
        $q.notify({ type: 'negative', message: msg || 'Failed to remove allocation.' })
      } finally {
        submittingMap.value[key] = false
      }
    })()
  })
}

// Pagination & Fetching
const fetchAllocatableData = async () => {
  if (!isParentContext.value || !authStore.tenantId) return
  
  await allocationStore.fetchAllocatableStocks(authStore.tenantId, {
    page: pagination.value.page,
    pageSize: pagination.value.rowsPerPage,
    search: searchText.value,
    shipmentId: shipmentFilter.value,
    stockTypeId: stockTypeFilter.value,
  })
  
  pagination.value.rowsNumber = allocationStore.allocatableTotal
}

const onRequest = (props: {
  pagination: {
    page: number
    rowsPerPage: number
    sortBy: string
    descending: boolean
  }
}) => {
  pagination.value.page = props.pagination.page
  pagination.value.rowsPerPage = props.pagination.rowsPerPage
  pagination.value.sortBy = props.pagination.sortBy
  pagination.value.descending = props.pagination.descending
  void fetchAllocatableData()
}

const onSearch = () => {
  pagination.value.page = 1
  void fetchAllocatableData()
}

// Filter Actions
const openFilterDrawer = () => {
  draftShipmentFilter.value = shipmentFilter.value
  draftStockTypeFilter.value = stockTypeFilter.value
  filterDrawerOpen.value = true
}

const onApplyDrawerFilters = () => {
  shipmentFilter.value = draftShipmentFilter.value
  stockTypeFilter.value = draftStockTypeFilter.value
  filterDrawerOpen.value = false
  pagination.value.page = 1
  void fetchAllocatableData()
}

const onResetFilters = () => {
  draftShipmentFilter.value = null
  draftStockTypeFilter.value = null
  shipmentFilter.value = null
  stockTypeFilter.value = null
  filterDrawerOpen.value = false
  pagination.value.page = 1
  void fetchAllocatableData()
}

const loadChildren = async () => {
  if (!authStore.tenantId) return
  try {
    const { data, error: err } = await supabase
      .from('tenants')
      .select('id, name')
      .eq('parent_id', authStore.tenantId)
    if (err) throw err
    childTenants.value = data || []
  } catch (err: unknown) {
    console.error('Failed to load child concerns', err)
  }
}

// Lifecycle
onMounted(async () => {
  if (isParentContext.value && authStore.tenantId) {
    await Promise.all([
      loadChildren(),
      shipmentStore.fetchShipments(authStore.tenantId),
      stockTypeStore.fetchStockTypes(authStore.tenantId),
      fetchAllocatableData(),
    ])
  }
})

// Watch context change
watch(
  () => [contextTenantId.value, isParentContext.value] as const,
  async ([newTenantId, parentCtx]) => {
    if (parentCtx && newTenantId) {
      await Promise.all([
        loadChildren(),
        shipmentStore.fetchShipments(newTenantId),
        stockTypeStore.fetchStockTypes(newTenantId),
        fetchAllocatableData(),
      ])
    }
  }
)
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.12);
}
.border-top {
  border-top: 1px solid rgba(0, 0, 0, 0.12);
}
</style>
