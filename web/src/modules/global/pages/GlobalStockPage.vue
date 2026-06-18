<template>
  <q-page class="q-pa-md inventory-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="row items-center q-gutter-sm q-mb-xs">
              <div class="text-h6 text-weight-bold">Global Stock</div>
              <ModuleNavBadge family="global" />
            </div>
            <div class="text-caption text-grey-8">
              Parent pool (source of truth). Use Allocate Stock to split quantities to child tenants.
            </div>
          </div>
          <div class="col-auto row items-center q-gutter-sm">
            <q-btn
              v-if="isParentContext"
              outline
              color="primary"
              no-caps
              class="pill-btn slim-btn"
              icon="call_split"
              label="Allocate Stock"
              :to="allocateStockRoute"
            />
            <div class="text-subtitle1 text-weight-medium text-grey-9">
              Total Stock: <span class="text-weight-bold text-primary">{{ globalStockStore.total }}</span>
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <div class="row items-center justify-between q-mb-md">
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
        <q-select
          v-if="showSearchInput"
          v-model="searchField"
          :options="searchFieldOptions"
          filled
          dense
          emit-value
          map-options
          class="soft-input"
          label="Search By"
          style="min-width: 140px;"
          @update:model-value="onSearchFieldChange"
        />
        <q-input
          v-if="showSearchInput"
          v-model="searchText"
          filled
          dense
          clearable
          class="soft-input toolbar-search"
          :label="`Search ${searchFieldLabel}`"
          @keyup.enter="() => { page = 1; void fetchGlobalStock() }"
          @clear="() => { page = 1; void fetchGlobalStock() }"
        >
          <template #prepend>
            <q-icon name="search" />
          </template>
          <template #append>
            <q-btn flat round dense icon="close" aria-label="Hide search" @click="onCloseSearch" />
          </template>
        </q-input>

        <q-btn flat round dense icon="filter_alt" aria-label="Filters" @click="filterDrawerOpen = true">
          <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
            {{ activeFilterCount }}
          </q-badge>
        </q-btn>
      </div>

      <div class="row items-center q-gutter-sm">
        <q-btn
          v-if="inventoryView === 'table'"
          outline
          color="primary"
          icon="view_column"
          label="Columns"
          no-caps
          size="sm"
          class="pill-btn slim-btn"
        >
          <q-menu>
            <q-list style="min-width: 240px">
              <q-item>
                <q-item-section>
                  <div class="text-subtitle2">Show Columns</div>
                </q-item-section>
              </q-item>
              <q-item>
                <q-item-section>
                  <q-checkbox
                    v-model="allSelectableTableColumnsSelected"
                    label="Select / Deselect All"
                  />
                </q-item-section>
              </q-item>
              <q-item>
                <q-item-section>
                  <q-option-group
                    v-model="selectedTableColumnNames"
                    type="checkbox"
                    :options="tableColumnSelectorOptions"
                  />
                </q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-btn>
        <q-btn
          v-if="selectedItemIds.length"
          flat
          icon="deselect"
          label="Clear Selection"
          @click="selectedItemIds = []"
        />
        <q-btn
          v-if="selectedItemIds.length"
          color="negative"
          no-caps
          icon="o_delete"
          :label="`Delete Selected (${selectedItemIds.length})`"
          @click="onDeleteSelected"
        />
        <q-btn-toggle
          v-model="inventoryView"
          unelevated
          toggle-color="primary"
          color="grey-3"
          text-color="grey-8"
          :options="inventoryViewOptions"
        />
      </div>
    </div>

    <PageInitialLoader v-if="globalStockStore.loading && !globalStockStore.items.length" message="Loading stock..." />

    <GlobalStockDetailsDialog
      v-model="detailsDialogOpen"
      :item="selectedDetailItem"
    />

    <q-table
      v-if="inventoryView === 'table' && !globalStockStore.loading"
      flat
      bordered
      row-key="id"
      :rows="globalStockStore.items"
      :columns="inventoryTableColumns"
      :visible-columns="visibleInventoryTableColumnNames"
      :pagination="{ rowsPerPage: 0 }"
      hide-bottom
      class="inventory-page__table inventory-q-table"
    >
      <template #body-cell-select="props">
        <q-td :props="props">
          <q-checkbox
            :model-value="selectedItemIds.includes(props.row.id)"
            @update:model-value="(checked) => onToggleSelect({ itemId: props.row.id, checked: Boolean(checked) })"
          />
        </q-td>
      </template>
      <template #body-cell-image="props">
        <q-td :props="props">
          <q-avatar rounded size="42px">
            <img
              :src="props.row.image_url || 'https://placehold.co/56x56?text=No+Image'"
              alt="item image"
              style="object-fit: contain;"
            />
          </q-avatar>
        </q-td>
      </template>
      <template #body-cell-shipment="props">
        <q-td :props="props">
          <span v-if="props.row.shipment?.shipment">
            #{{ props.row.shipment.shipment.tenant_shipment_id ?? props.row.shipment.shipment.id }} - {{ props.row.shipment.shipment.name }}
          </span>
          <span v-else>-</span>
        </q-td>
      </template>
      <template #body-cell-actions="props">
        <q-td :props="props">
          <q-btn flat round dense icon="visibility" color="primary" @click="openDetailsDialog(props.row)" />
        </q-td>
      </template>
      <template #header-cell-select="props">
        <q-th :props="props">
          <q-checkbox
            :model-value="isAllVisibleSelected"
            @update:model-value="onToggleSelectAllCheckbox"
          />
        </q-th>
      </template>
      <template #no-data>
        <div class="full-width text-center text-grey-7 q-py-md">No stock items found.</div>
      </template>
    </q-table>

    <InventoryCompactCard
      v-else-if="!globalStockStore.loading"
      :items="globalStockStore.items"
      @view-details="openDetailsDialog"
    />

    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <q-select
        v-model="shipmentIdFilter"
        :options="shipmentOptions"
        emit-value
        map-options
        filled
        dense
        clearable
        class="soft-input q-mb-md"
        label="Shipment"
        @update:model-value="onShipmentFilterChange"
      />
      <div class="row q-gutter-sm justify-end">
        <q-btn flat no-caps label="Reset" @click="onResetFilters" />
      </div>
    </FilterSidebar>

    <div v-if="totalPages > 1" class="row justify-center q-mt-md">
      <q-pagination
        v-model="page"
        :max="totalPages"
        :max-pages="7"
        direction-links
        boundary-links
        @update:model-value="() => { void fetchGlobalStock() }"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useQuasar } from 'quasar'

import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import ModuleNavBadge from 'src/components/ui/ModuleNavBadge.vue'
import FilterSidebar from 'src/components/FilterSidebar.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import InventoryCompactCard from 'src/modules/inventory/components/InventoryCompactCard.vue'
import type { InventoryItemWithStock } from 'src/modules/inventory/types'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'
import type { Shipment } from 'src/modules/shipment/types'
import { handleApiFailure } from 'src/utils/appFeedback'

import GlobalStockDetailsDialog from '../components/GlobalStockDetailsDialog.vue'
import { useGlobalStockStore } from '../stores/globalStockStore'
import type { GlobalStockSearchField } from '../types'

const authStore = useAuthStore()
const tenantStore = useTenantStore()
const globalStockStore = useGlobalStockStore()
const shipmentStore = useShipmentStore()
const $q = useQuasar()

const detailsDialogOpen = ref(false)
const selectedDetailItem = ref<InventoryItemWithStock | null>(null)
const searchField = ref<GlobalStockSearchField>('name')
const searchText = ref('')
const shipmentIdFilter = ref<number | null>(null)
const page = ref(1)
const selectedItemIds = ref<number[]>([])
const inventoryView = ref<'compact' | 'table'>('compact')
const showSearchInput = ref(false)
const filterDrawerOpen = ref(false)

const inventoryViewOptions = [
  { icon: 'table_rows', value: 'table' as const },
  { icon: 'grid_view', value: 'compact' as const },
]

const inventoryTableColumns = [
  {
    name: 'select',
    label: '',
    field: 'select',
    align: 'left' as const,
    style: 'width: 44px; min-width: 44px;',
    headerStyle: 'width: 44px; min-width: 44px;',
    classes: 'inventory-page__sticky-col inventory-page__sticky-col--select',
    headerClasses: 'inventory-page__sticky-col inventory-page__sticky-col--select',
  },
  {
    name: 'image',
    label: 'Image',
    field: 'image_url',
    align: 'left' as const,
    style: 'width: 72px; min-width: 72px;',
    headerStyle: 'width: 72px; min-width: 72px;',
    classes: 'inventory-page__sticky-col inventory-page__sticky-col--image',
    headerClasses: 'inventory-page__sticky-col inventory-page__sticky-col--image',
  },
  {
    name: 'name',
    label: 'Name',
    field: 'name',
    align: 'left' as const,
    style: 'min-width: 220px; white-space: normal;',
    classes: 'inventory-page__name-cell',
    headerStyle: 'min-width: 220px;',
  },
  { name: 'barcode', label: 'Barcode', field: 'barcode', align: 'left' as const },
  { name: 'product_code', label: 'Product Code', field: 'product_code', align: 'left' as const },
  { name: 'shipment', label: 'Shipment', field: 'shipment', align: 'left' as const },
  { name: 'available', label: 'Available', field: (row: InventoryItemWithStock) => row.quantities.available, align: 'right' as const },
  { name: 'reserved', label: 'Reserved', field: (row: InventoryItemWithStock) => row.quantities.reserved, align: 'right' as const },
  { name: 'damaged', label: 'Damaged', field: (row: InventoryItemWithStock) => row.quantities.damaged, align: 'right' as const },
  { name: 'stolen', label: 'Stolen', field: (row: InventoryItemWithStock) => row.quantities.stolen, align: 'right' as const },
  { name: 'expired', label: 'Expired', field: (row: InventoryItemWithStock) => row.quantities.expired, align: 'right' as const },
  { name: 'open_box', label: 'Open Box', field: (row: InventoryItemWithStock) => row.quantities.open_box, align: 'right' as const },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' as const },
]

const alwaysVisibleInventoryTableColumns = ['select', 'image', 'name'] as const
const selectableInventoryTableColumns = inventoryTableColumns
  .map((column) => column.name)
  .filter((name) => !alwaysVisibleInventoryTableColumns.includes(name as (typeof alwaysVisibleInventoryTableColumns)[number]))
const selectedTableColumnNames = ref<string[]>([...selectableInventoryTableColumns])
const tableColumnSelectorOptions = inventoryTableColumns
  .filter((column) => selectableInventoryTableColumns.includes(column.name))
  .map((column) => ({ label: column.label, value: column.name }))

const allSelectableTableColumnsSelected = computed({
  get: () => selectableInventoryTableColumns.every((name) => selectedTableColumnNames.value.includes(name)),
  set: (checked: boolean) => {
    selectedTableColumnNames.value = checked ? [...selectableInventoryTableColumns] : []
  },
})

const visibleInventoryTableColumnNames = computed<string[]>(() => [
  ...alwaysVisibleInventoryTableColumns,
  ...selectedTableColumnNames.value,
])

const isAllVisibleSelected = computed(() =>
  globalStockStore.items.length > 0 &&
  globalStockStore.items.every((item) => selectedItemIds.value.includes(item.id)),
)

const totalPages = computed(() => Math.max(1, globalStockStore.total_pages || 1))

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

const searchFieldOptions = [
  { label: 'Name', value: 'name' as const },
  { label: 'Barcode', value: 'barcode' as const },
  { label: 'Product Code', value: 'product_code' as const },
]

const searchFieldLabel = computed(() => {
  if (searchField.value === 'barcode') return 'Barcode'
  if (searchField.value === 'product_code') return 'Product Code'
  return 'Name'
})

const activeFilterCount = computed(() => {
  let count = 0
  if (searchField.value !== 'name') count += 1
  if (shipmentIdFilter.value != null) count += 1
  return count
})

const shipmentsById = computed(() => {
  const map = new Map<number, Shipment>()
  for (const shipment of shipmentStore.shipments) {
    map.set(shipment.id, shipment)
  }
  return map
})

const openDetailsDialog = (item: InventoryItemWithStock) => {
  selectedDetailItem.value = item
  detailsDialogOpen.value = true
}

const effectiveParentTenantId = computed(() => {
  const current =
    tenantStore.selectedTenant ??
    tenantStore.items.find((tenant) => tenant.id === authStore.tenantId) ??
    null
  if (!current) return authStore.tenantId
  return current.parent_id ?? current.id
})

const isParentContext = computed(() => {
  const tenantId = tenantStore.selectedTenantId ?? authStore.tenantId
  return tenantId != null && effectiveParentTenantId.value != null && tenantId === effectiveParentTenantId.value
})

const allocateStockRoute = computed(() => {
  const slug = tenantStore.selectedTenantSlug ?? authStore.tenantSlug
  return slug ? `/${slug}/app/global/stock/allocate` : '/app/global/stock/allocate'
})

const fetchGlobalStock = async () => {
  const tenantId = effectiveParentTenantId.value
  if (!tenantId) {
    handleApiFailure({ success: false, error: 'Tenant is not selected.' }, 'Tenant is not selected.')
    return
  }

  const result = await globalStockStore.fetchGlobalStock(
    {
      tenant_id: tenantId,
      page: page.value,
      page_size: globalStockStore.page_size,
      search: searchText.value.trim() || null,
      search_field: searchField.value,
      shipment_id: shipmentIdFilter.value,
      exclude_zero_qty: true,
    },
    shipmentsById.value,
  )

  if (!result.success) {
    handleApiFailure(result, result.error ?? 'Failed to load global stock.')
    return
  }

  const visibleIds = new Set(globalStockStore.items.map((item) => item.id))
  selectedItemIds.value = selectedItemIds.value.filter((id) => visibleIds.has(id))
}

const onCloseSearch = () => {
  showSearchInput.value = false
  if (!searchText.value) return
  searchText.value = ''
  page.value = 1
  void fetchGlobalStock()
}

const onResetFilters = () => {
  searchField.value = 'name'
  shipmentIdFilter.value = null
  searchText.value = ''
  showSearchInput.value = false
  page.value = 1
  filterDrawerOpen.value = false
  void fetchGlobalStock()
}

const onSearchFieldChange = () => {
  page.value = 1
  void fetchGlobalStock()
}

const onShipmentFilterChange = () => {
  page.value = 1
  void fetchGlobalStock()
}

const onToggleSelect = (payload: { itemId: number; checked: boolean }) => {
  if (payload.checked) {
    if (!selectedItemIds.value.includes(payload.itemId)) {
      selectedItemIds.value = [...selectedItemIds.value, payload.itemId]
    }
    return
  }
  selectedItemIds.value = selectedItemIds.value.filter((id) => id !== payload.itemId)
}

const onDeleteSelected = () => {
  if (!selectedItemIds.value.length) return
  const idsToDelete = [...selectedItemIds.value]
  $q.dialog({
    title: 'Delete Selected Stock Items',
    message: `Are you sure you want to delete ${idsToDelete.length} selected item(s)? This will also delete related stock records.`,
    cancel: true,
    persistent: true,
    ok: {
      label: 'Delete All',
      color: 'negative',
      unelevated: true,
    },
  }).onOk(() => {
    void (async () => {
      for (const id of idsToDelete) {
        const result = await globalStockStore.deleteGlobalStock(id)
        if (!result.success) {
          handleApiFailure(result, result.error ?? 'Failed to delete one or more stock items.')
          return
        }
      }
      selectedItemIds.value = []
      await fetchGlobalStock()
    })()
  })
}

const onSelectAllVisible = () => {
  selectedItemIds.value = globalStockStore.items.map((item) => item.id)
}

const onToggleSelectAllCheckbox = (checked: boolean | null) => {
  if (checked) {
    onSelectAllVisible()
    return
  }
  selectedItemIds.value = selectedItemIds.value.filter(
    (id) => !globalStockStore.items.some((item) => item.id === id),
  )
}

onMounted(() => {
  const tenantId = effectiveParentTenantId.value
  if (!tenantId) {
    handleApiFailure({ success: false, error: 'Tenant is not selected.' }, 'Tenant is not selected.')
    return
  }

  void Promise.all([
    shipmentStore.fetchShipments(tenantId),
    fetchGlobalStock(),
  ])
})

watch(
  () => tenantStore.selectedTenantId,
  () => {
    void fetchGlobalStock()
  },
)
</script>

