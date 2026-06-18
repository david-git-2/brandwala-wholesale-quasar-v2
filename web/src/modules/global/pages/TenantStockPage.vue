<template>
  <q-page class="q-pa-md inventory-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="row items-center q-gutter-sm q-mb-xs">
              <div class="text-h6 text-weight-bold">{{ pageTitle }}</div>
              <ModuleNavBadge :family="isAllocatePage ? 'global' : 'tenant_stock'" />
            </div>
            <div class="text-caption text-grey-8">{{ pageCaption }}</div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-banner v-if="isAllocatePage && !isParentContext" class="bg-orange-1 text-orange-10 q-mb-md rounded-borders">
      Allocate Stock is for parent tenant admins. Switch to the parent tenant in the header dropdown.
    </q-banner>

    <template v-if="!isAllocatePage">
      <div class="row items-center q-gutter-sm q-mb-md">
        <q-input
          v-model="searchText"
          filled
          dense
          clearable
          class="soft-input col-grow"
          label="Search allocated stock"
          @keyup.enter="() => { page = 1; void fetchTenantStock() }"
          @clear="() => { page = 1; void fetchTenantStock() }"
        >
          <template #prepend>
            <q-icon name="search" />
          </template>
        </q-input>
        <q-btn
          v-if="isParentContext"
          outline
          color="primary"
          no-caps
          class="pill-btn slim-btn"
          icon="call_split"
          label="Allocate Stock"
          :to="allocateRoute"
        />
      </div>

      <PageInitialLoader v-if="loading && !items.length" message="Loading tenant stock..." />

      <GlobalStockDetailsDialog v-model="detailsDialogOpen" :item="selectedDetailItem" />

      <InventoryCompactCard
        v-if="!loading"
        :items="items"
        @view-details="openDetailsDialog"
      />

      <div v-if="totalPages > 1" class="row justify-center q-mt-md">
        <q-pagination
          v-model="page"
          :max="totalPages"
          :max-pages="7"
          direction-links
          boundary-links
          @update:model-value="() => { void fetchTenantStock() }"
        />
      </div>
    </template>

    <template v-else-if="isParentContext">
      <div class="row items-center q-gutter-sm q-mb-md">
        <q-input
          v-model="allocateSearchText"
          filled
          dense
          clearable
          class="soft-input col-grow"
          label="Search global stock to allocate"
          @keyup.enter="() => { allocatePage = 1; void loadAllocateStock() }"
          @clear="() => { allocatePage = 1; void loadAllocateStock() }"
        >
          <template #prepend>
            <q-icon name="search" />
          </template>
        </q-input>
        <q-btn flat round dense icon="filter_alt" aria-label="Filters" @click="allocateFilterDrawerOpen = true">
          <q-badge v-if="allocateActiveFilterCount > 0" color="primary" rounded floating>
            {{ allocateActiveFilterCount }}
          </q-badge>
        </q-btn>
      </div>

      <FilterSidebar v-model="allocateFilterDrawerOpen" title="Filters">
        <q-select
          v-model="allocateShipmentIdFilter"
          :options="shipmentOptions"
          emit-value
          map-options
          filled
          dense
          clearable
          class="soft-input q-mb-md"
          label="Shipment"
          @update:model-value="onAllocateShipmentFilterChange"
        />
        <div class="row q-gutter-sm justify-end">
          <q-btn flat no-caps label="Reset" @click="onResetAllocateFilters" />
        </div>
      </FilterSidebar>

      <PageInitialLoader
        v-if="allocateLoading && !allocateStockRows.length"
        message="Loading stock to allocate..."
      />

      <div v-else-if="!childTenants.length" class="text-body2 text-grey-8 q-pa-md">
        No child tenants found for this parent. Create child tenants first.
      </div>

      <div v-else class="row q-col-gutter-md q-row-gutter-md">
        <div
          v-for="stock in allocateStockRows"
          :key="stock.id"
          class="col-12 col-sm-6 col-md-4 col-lg-3"
        >
          <StockAllocateCard
            :stock="stock"
            :child-tenants="childTenants"
            :quantities="allocationDrafts[stock.id] ?? {}"
            :saving="savingStockId === stock.id"
            @update:quantities="onDraftQuantityChange"
            @save="onSaveStockAllocations"
          />
        </div>
      </div>

      <div v-if="allocateTotalPages > 1" class="row justify-center q-mt-md">
        <q-pagination
          v-model="allocatePage"
          :max="allocateTotalPages"
          :max-pages="7"
          direction-links
          boundary-links
          @update:model-value="() => { void loadAllocateStock() }"
        />
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'

import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import ModuleNavBadge from 'src/components/ui/ModuleNavBadge.vue'
import FilterSidebar from 'src/components/FilterSidebar.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'
import InventoryCompactCard from 'src/modules/inventory/components/InventoryCompactCard.vue'
import type { InventoryItemWithStock } from 'src/modules/inventory/types'
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'

import GlobalStockDetailsDialog from '../components/GlobalStockDetailsDialog.vue'
import StockAllocateCard from '../components/StockAllocateCard.vue'
import { globalRepository } from '../repositories/globalRepository'
import type { AllocateChildTenant, ChildStockAllocationRow, GlobalStockRow, StockNetworkRow } from '../types'
import { mapStockNetworkToInventoryView } from '../utils/mapStockNetworkRow'

const authStore = useAuthStore()
const tenantStore = useTenantStore()
const shipmentStore = useShipmentStore()
const route = useRoute()

const isAllocatePage = computed(() => route.name === 'app-global-stock-allocate-page')

const pageTitle = computed(() => (isAllocatePage.value ? 'Allocate Stock' : 'Tenant Stock'))

const pageCaption = computed(() => {
  if (isAllocatePage.value) {
    return 'Enter quantities under each product for every child tenant. Save per card when done.'
  }
  return `Allocated stock for ${contextTenantLabel.value}. Global pool is the separate Global Stock module.`
})

const loading = ref(false)
const items = ref<InventoryItemWithStock[]>([])
const page = ref(1)
const pageSize = 20
const total = ref(0)
const searchText = ref('')
const detailsDialogOpen = ref(false)
const selectedDetailItem = ref<InventoryItemWithStock | null>(null)

const allocateLoading = ref(false)
const savingStockId = ref<number | null>(null)
const allocateStockRows = ref<GlobalStockRow[]>([])
const allocateSearchText = ref('')
const allocatePage = ref(1)
const allocatePageSize = 12
const allocateTotal = ref(0)
const allocateShipmentIdFilter = ref<number | null>(null)
const allocateFilterDrawerOpen = ref(false)
const savedAllocations = ref<ChildStockAllocationRow[]>([])
const allocationDrafts = ref<Record<number, Record<number, number>>>({})

const contextTenantId = computed(
  () => tenantStore.selectedTenantId ?? authStore.tenantId ?? null,
)

const effectiveParentTenantId = computed(() => {
  const current =
    tenantStore.selectedTenant ??
    tenantStore.items.find((tenant) => tenant.id === authStore.tenantId) ??
    null
  if (!current) return authStore.tenantId
  return current.parent_id ?? current.id
})

const isParentContext = computed(
  () =>
    contextTenantId.value != null &&
    effectiveParentTenantId.value != null &&
    contextTenantId.value === effectiveParentTenantId.value,
)

const allocateRoute = computed(() => {
  const slug = tenantStore.selectedTenantSlug ?? authStore.tenantSlug
  return slug ? `/${slug}/app/global/stock/allocate` : '/app/global/stock/allocate'
})

const contextTenantLabel = computed(() => {
  const tenant =
    tenantStore.selectedTenant ??
    tenantStore.availableAdminTenants.find((t) => t.id === contextTenantId.value)
  return tenant?.name ?? 'this tenant'
})

const totalPages = computed(() => Math.max(1, Math.ceil(total.value / pageSize)))

const allocateTotalPages = computed(() => Math.max(1, Math.ceil(allocateTotal.value / allocatePageSize)))

const childTenants = computed<AllocateChildTenant[]>(() =>
  tenantStore.availableAdminTenants
    .filter((tenant) => tenant.parent_id === effectiveParentTenantId.value)
    .map((tenant) => ({ id: tenant.id, name: tenant.name })),
)

const shipmentOptions = computed(() =>
  [
    { label: 'All', value: null as number | null },
    ...shipmentStore.shipments
      .filter((shipment) => shipment.inventory_added === true)
      .map((shipment) => ({
        label: `#${shipment.tenant_shipment_id ?? shipment.id} ${shipment.name}`,
        value: shipment.id,
      })),
  ],
)

const allocateActiveFilterCount = computed(() => (allocateShipmentIdFilter.value != null ? 1 : 0))

const fetchTenantStock = async () => {
  const tenantId = contextTenantId.value
  if (!tenantId) return

  loading.value = true
  try {
    const result = await globalRepository.searchStockNetwork({
      context_tenant_id: tenantId,
      mode: 'page',
      search: searchText.value.trim() || null,
      page: page.value,
      page_size: pageSize,
    })
    total.value = result.meta.total
    items.value = result.data.map((row: StockNetworkRow) => mapStockNetworkToInventoryView(row))
  } catch (error) {
    handleApiFailure(
      { success: false, error: error instanceof Error ? error.message : 'Failed to load tenant stock.' },
      'Failed to load tenant stock.',
    )
  } finally {
    loading.value = false
  }
}

const buildDraftForStock = (stockId: number) => {
  const draft: Record<number, number> = {}
  for (const child of childTenants.value) {
    const saved = savedAllocations.value.find(
      (row) => row.stock_id === stockId && row.child_tenant_id === child.id,
    )
    draft[child.id] = saved?.quantity ?? 0
  }
  return draft
}

const syncAllocationDrafts = () => {
  const next: Record<number, Record<number, number>> = {}
  for (const stock of allocateStockRows.value) {
    next[stock.id] = buildDraftForStock(stock.id)
  }
  allocationDrafts.value = next
}

const loadSavedAllocations = async () => {
  const parentId = effectiveParentTenantId.value
  if (!parentId) return

  savedAllocations.value = await globalRepository.listChildStockAllocations(parentId)
}

const loadAllocateStock = async () => {
  const parentId = effectiveParentTenantId.value
  if (!parentId) return

  allocateLoading.value = true
  try {
    const result = await globalRepository.listGlobalStockPage({
      tenant_id: parentId,
      page: allocatePage.value,
      page_size: allocatePageSize,
      search: allocateSearchText.value.trim() || null,
      shipment_id: allocateShipmentIdFilter.value,
    })
    allocateStockRows.value = result.data
    allocateTotal.value = result.meta.total
    syncAllocationDrafts()
  } catch (error) {
    handleApiFailure(
      { success: false, error: error instanceof Error ? error.message : 'Failed to load stock.' },
      'Failed to load stock.',
    )
  } finally {
    allocateLoading.value = false
  }
}

const onDraftQuantityChange = (stockId: number, childTenantId: number, quantity: number) => {
  const current = allocationDrafts.value[stockId] ?? {}
  allocationDrafts.value = {
    ...allocationDrafts.value,
    [stockId]: {
      ...current,
      [childTenantId]: quantity,
    },
  }
}

const onSaveStockAllocations = async (stockId: number) => {
  const parentId = effectiveParentTenantId.value
  const stock = allocateStockRows.value.find((row) => row.id === stockId)
  const draft = allocationDrafts.value[stockId]
  if (!parentId || !stock || !draft) return

  const allocatedTotal = childTenants.value.reduce(
    (sum, child) => sum + Math.max(0, draft[child.id] ?? 0),
    0,
  )
  if (allocatedTotal > stock.excellent_qty) {
    handleApiFailure(
      { success: false, error: 'Allocated quantity exceeds global pool.' },
      'Allocated quantity exceeds global pool.',
    )
    return
  }

  savingStockId.value = stockId
  try {
    await Promise.all(
      childTenants.value.map((child) =>
        globalRepository.upsertChildStockAllocation({
          parent_tenant_id: parentId,
          child_tenant_id: child.id,
          stock_id: stockId,
          quantity: Math.max(0, draft[child.id] ?? 0),
        }),
      ),
    )
    showSuccessNotification(`Allocations saved for ${stock.name}.`)
    await loadSavedAllocations()
    syncAllocationDrafts()
  } catch (error) {
    handleApiFailure(
      { success: false, error: error instanceof Error ? error.message : 'Failed to save allocation.' },
      'Failed to save allocation.',
    )
  } finally {
    savingStockId.value = null
  }
}

const loadAllocatePageData = async () => {
  const parentId = effectiveParentTenantId.value
  if (parentId) {
    await shipmentStore.fetchShipments(parentId)
  }
  await loadSavedAllocations()
  await loadAllocateStock()
}

const onAllocateShipmentFilterChange = () => {
  allocatePage.value = 1
  void loadAllocateStock()
}

const onResetAllocateFilters = () => {
  allocateShipmentIdFilter.value = null
  allocateSearchText.value = ''
  allocatePage.value = 1
  allocateFilterDrawerOpen.value = false
  void loadAllocateStock()
}

const openDetailsDialog = (item: InventoryItemWithStock) => {
  selectedDetailItem.value = item
  detailsDialogOpen.value = true
}

watch(
  () => [contextTenantId.value, tenantStore.selectedTenantId, isAllocatePage.value] as const,
  () => {
    if (isAllocatePage.value) {
      if (isParentContext.value) {
        allocatePage.value = 1
        void loadAllocatePageData()
      }
      return
    }
    page.value = 1
    void fetchTenantStock()
  },
)

onMounted(() => {
  if (isAllocatePage.value) {
    if (isParentContext.value) {
      void loadAllocatePageData()
    }
    return
  }
  void fetchTenantStock()
})
</script>
