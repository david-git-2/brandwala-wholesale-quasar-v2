<template>
  <q-page class="q-pa-md inventory-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Inventory</div>
            <div class="text-caption text-grey-8">Manage stock, quantities, and item-level inventory records</div>
          </div>
          <div class="col-auto row items-center q-gutter-sm" />
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
          @keyup.enter="() => { page = 1; void fetchInventoryItems() }"
          @clear="() => { page = 1; void fetchInventoryItems() }"
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

    <InventoryItemDialog
      v-model="isAddDialogOpen"
      :shipment-options="warehouseReceivedShipmentOptions"
      @save="onSaveItem"
    />
    <InventoryDetailsDialog
      v-model="detailsDialogOpen"
      :item="selectedDetailItem"
      @refresh="fetchInventoryItems"
    />
    <q-table
      v-if="inventoryView === 'table'"
      flat
      bordered
      row-key="id"
      :rows="inventoryStore.items"
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
          {{ props.row.shipment?.shipment?.name ?? '-' }}
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
        <div class="full-width text-center text-grey-7 q-py-md">No inventory items found.</div>
      </template>
    </q-table>
    <InventoryCompactCard v-else :items="inventoryStore.items" @view-details="openDetailsDialog" />

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
        @update:model-value="() => { void fetchInventoryItems() }"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useQuasar } from 'quasar'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'
import { useProductStore } from 'src/modules/products/stores/productStore'
import { handleApiFailure } from 'src/utils/appFeedback'
import FilterSidebar from 'src/components/FilterSidebar.vue'
import InventoryCompactCard from '../components/InventoryCompactCard.vue'
import InventoryItemDialog from '../components/InventoryItemDialog.vue'
import InventoryDetailsDialog from '../components/InventoryDetailsDialog.vue'
import { useInventoryStore } from '../stores/inventoryStore'
import type { CreateInventoryItemInput, InventoryItemWithStock } from '../types'

const authStore = useAuthStore()
const inventoryStore = useInventoryStore()
const shipmentStore = useShipmentStore()
const productStore = useProductStore()
const $q = useQuasar()

const isAddDialogOpen = ref(false)
const detailsDialogOpen = ref(false)
const selectedDetailItem = ref<InventoryItemWithStock | null>(null)
const searchField = ref<'name' | 'barcode' | 'product_code'>('name')
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
  inventoryStore.items.length > 0 &&
  inventoryStore.items.every((item) => selectedItemIds.value.includes(item.id)),
)

const totalPages = computed(() =>
  Math.max(1, inventoryStore.total_pages || 1),
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

const warehouseReceivedShipmentOptions = computed(() =>
  shipmentStore.shipments
    .filter((shipment) => shipment.status?.trim().toLowerCase() === 'warehouse received')
    .map((shipment) => ({
      label: `#${shipment.tenant_shipment_id ?? shipment.id} ${shipment.name}`,
      value: shipment.id,
    })),
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

const openDetailsDialog = (item: InventoryItemWithStock) => {
  selectedDetailItem.value = item
  detailsDialogOpen.value = true
}

const fetchInventoryItems = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) {
    handleApiFailure({ success: false, error: 'Tenant is not selected.' }, 'Tenant is not selected.')
    return
  }

  const filters: Record<string, unknown> = {}
  if (searchText.value.trim()) {
    filters[searchField.value] = searchText.value.trim()
  }
  if (shipmentIdFilter.value != null && Number.isFinite(shipmentIdFilter.value)) {
    filters.shipment_id = shipmentIdFilter.value
  }

  await inventoryStore.fetchInventoryItems({
    tenant_id: tenantId,
    filters,
    page: page.value,
    page_size: inventoryStore.page_size,
    sortBy: 'id',
    sortOrder: 'desc',
  })

  const visibleIds = new Set(inventoryStore.items.map((item) => item.id))
  selectedItemIds.value = selectedItemIds.value.filter((id) => visibleIds.has(id))
}

const onCloseSearch = () => {
  showSearchInput.value = false
  if (!searchText.value) return
  searchText.value = ''
  page.value = 1
  void fetchInventoryItems()
}

const onResetFilters = () => {
  searchField.value = 'name'
  shipmentIdFilter.value = null
  searchText.value = ''
  showSearchInput.value = false
  page.value = 1
  filterDrawerOpen.value = false
  void fetchInventoryItems()
}

const onSearchFieldChange = () => {
  page.value = 1
  void fetchInventoryItems()
}

const onShipmentFilterChange = () => {
  page.value = 1
  void fetchInventoryItems()
}

const onSaveItem = async (
  payload: Omit<CreateInventoryItemInput, 'tenant_id' | 'source_type' | 'source_id' | 'status'> & {
    available_quantity: number
    shipment_id: number | null
  },
) => {
  const tenantId = authStore.tenantId

  if (!tenantId) {
    handleApiFailure({ success: false, error: 'Tenant is not selected.' }, 'Tenant is not selected.')
    return
  }

  const { available_quantity, shipment_id, ...itemPayload } = payload

  const createProductResult = await productStore.createProduct({
    tenant_id: tenantId,
    name: itemPayload.name,
    image_url: itemPayload.image_url,
    barcode: itemPayload.barcode ?? null,
    product_code: itemPayload.product_code ?? null,
    price_gbp: null,
    country_of_origin: null,
    brand: null,
    category: null,
    available_units: null,
    tariff_code: null,
    languages: null,
    batch_code_manufacture_date: null,
    expire_date: itemPayload.expire_date,
    minimum_order_quantity: null,
    product_weight: null,
    package_weight: null,
    vendor_code: null,
    market_code: null,
    is_available: true,
  })

  if (!createProductResult.success || !createProductResult.data?.id) {
    handleApiFailure(
      createProductResult,
      createProductResult.error ?? 'Failed to create product.',
    )
    return
  }

  const result = await inventoryStore.createInventoryItem({
    tenant_id: tenantId,
    source_type: shipment_id != null ? 'shipment' : 'manual',
    source_id: shipment_id ?? createProductResult.data.id,
    product_id: createProductResult.data.id,
    status: 'active',
    ...itemPayload,
  })

  if (!result.success) {
    handleApiFailure(result, result.error ?? 'Failed to create inventory item.')
    return
  }

  const createdItemId = result.data?.id
  if (!createdItemId) {
    handleApiFailure(
      { success: false, error: 'Created inventory item id is missing.' },
      'Created inventory item id is missing.',
    )
    return
  }

  const stockResult = await inventoryStore.createInventoryStock({
    inventory_item_id: createdItemId,
    available_quantity,
    reserved_quantity: 0,
    damaged_quantity: 0,
    stolen_quantity: 0,
    expired_quantity: 0,
    open_box_quantity: 0,
  })

  if (!stockResult.success) {
    handleApiFailure(stockResult, stockResult.error ?? 'Failed to create inventory stock.')
    return
  }
}

// Removed onSaveQuantity



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
    title: 'Delete Selected Inventory Items',
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
        const result = await inventoryStore.deleteInventoryItem({ id })
        if (!result.success) {
          handleApiFailure(result, result.error ?? 'Failed to delete one or more inventory items.')
          return
        }
      }
      selectedItemIds.value = []
      await fetchInventoryItems()
    })()
  })
}

const onSelectAllVisible = () => {
  selectedItemIds.value = inventoryStore.items.map((item) => item.id)
}
const onToggleSelectAllCheckbox = (checked: boolean | null) => {
  if (checked) {
    onSelectAllVisible()
    return
  }
  selectedItemIds.value = selectedItemIds.value.filter(
    (id) => !inventoryStore.items.some((item) => item.id === id),
  )
}

// Removed onSaveDate

onMounted(() => {
  const tenantId = authStore.tenantId
  if (!tenantId) {
    handleApiFailure({ success: false, error: 'Tenant is not selected.' }, 'Tenant is not selected.')
    return
  }

  void Promise.all([
    shipmentStore.fetchShipments(tenantId),
    fetchInventoryItems(),
  ])
})
</script>
<style scoped>
.inventory-page {
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
.pill-btn { border-radius: 999px; }
.slim-btn { min-height: 32px; padding-left: 10px; padding-right: 10px; }
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
.toolbar-left { min-width: 0; }
.toolbar-search { width: min(320px, 75vw); }
.inventory-page__table :deep(.q-table__middle) {
  max-height: calc(100vh - 340px);
  overflow: auto;
}
.inventory-page__table :deep(.q-table) {
  table-layout: auto;
  min-width: 1200px;
}
.inventory-page__table :deep(.q-table th),
.inventory-page__table :deep(.q-table td) {
  white-space: nowrap;
}
.inventory-page__table :deep(.inventory-q-table thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background: var(--bw-theme-surface, #fff);
}
.inventory-page__table :deep(.inventory-q-table td:first-child),
.inventory-page__table :deep(.inventory-q-table th:first-child) {
  position: sticky;
  left: 0;
}
.inventory-page__table :deep(.inventory-q-table td:nth-child(2)),
.inventory-page__table :deep(.inventory-q-table th:nth-child(2)) {
  position: sticky;
  left: 44px;
}
.inventory-page__table :deep(.inventory-q-table td:first-child) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}
.inventory-page__table :deep(.inventory-q-table td:nth-child(2)) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}
.inventory-page__table :deep(.inventory-q-table tr:first-child th:first-child) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}
.inventory-page__table :deep(.inventory-q-table tr:first-child th:nth-child(2)) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}
.inventory-page__table :deep(.inventory-page__name-cell) {
  white-space: nowrap !important;
}
</style>
