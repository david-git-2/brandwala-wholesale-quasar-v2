<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-h5">Inventory</div>
      <q-btn color="primary" label="Add Item" @click="openAddDialog" />
    </div>

    <div class="row q-col-gutter-md q-mb-md">
      <div class="col-12 col-md-6">
        <div class="row no-wrap q-col-gutter-sm">
          <div class="col-5">
            <q-select
              v-model="searchField"
              :options="searchFieldOptions"
              emit-value
              map-options
              outlined
              dense
              label="Search by"
            />
          </div>
          <div class="col-7">
            <q-input
              v-model="searchText"
              outlined
              dense
              :label="`Search ${searchFieldLabel}`"
              clearable
              @keyup.enter="() => { page = 1; void fetchInventoryItems() }"
            />
          </div>
        </div>
      </div>
      <div class="col-12 col-md-3">
        <q-select
          v-model="shipmentIdFilter"
          :options="shipmentOptions"
          emit-value
          map-options
          outlined
          dense
          label="Filter by shipment"
          clearable
          @update:model-value="() => { page = 1; void fetchInventoryItems() }"
        />
      </div>
      <div class="col-12 col-md-4 row items-center q-gutter-sm">
        <q-btn
          flat
          label="Reset"
          @click="() => { searchText = ''; searchField = 'name'; shipmentIdFilter = null; page = 1; void fetchInventoryItems() }"
        />
      </div>
    </div>

    <InventoryItemDialog v-model="isAddDialogOpen" @save="onSaveItem" />
    <InventoryCard
      :items="inventoryStore.items"
      @save-quantity="onSaveQuantity"
      @save-date="onSaveDate"
      @delete-item="onDeleteItem"
    />

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
import InventoryCard from '../components/InventoryCard.vue'
import InventoryItemDialog from '../components/InventoryItemDialog.vue'
import { useInventoryStore } from '../stores/inventoryStore'
import type { CreateInventoryItemInput, InventoryItemWithStock } from '../types'

const authStore = useAuthStore()
const inventoryStore = useInventoryStore()
const shipmentStore = useShipmentStore()
const productStore = useProductStore()
const $q = useQuasar()

const isAddDialogOpen = ref(false)
const searchField = ref<'name' | 'barcode' | 'product_code'>('name')
const searchText = ref('')
const shipmentIdFilter = ref<number | null>(null)
const page = ref(1)

const totalPages = computed(() =>
  Math.max(1, inventoryStore.total_pages || 1),
)

const shipmentOptions = computed(() =>
  [
    { label: 'All', value: null as number | null },
    ...shipmentStore.shipments.map((shipment) => ({
      label: shipment.name,
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
}

const openAddDialog = () => {
  isAddDialogOpen.value = true
}

const onSaveItem = async (
  payload: Omit<CreateInventoryItemInput, 'tenant_id' | 'source_type' | 'source_id' | 'status'> & {
    available_quantity: number
  },
) => {
  const tenantId = authStore.tenantId

  if (!tenantId) {
    handleApiFailure({ success: false, error: 'Tenant is not selected.' }, 'Tenant is not selected.')
    return
  }

  const { available_quantity, ...itemPayload } = payload

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
    source_type: 'manual',
    source_id: createProductResult.data.id,
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
  })

  if (!stockResult.success) {
    handleApiFailure(stockResult, stockResult.error ?? 'Failed to create inventory stock.')
    return
  }
}

const onSaveQuantity = async (payload: {
  item: InventoryItemWithStock
  field: 'available' | 'reserved' | 'damaged' | 'stolen' | 'expired'
  value: number
}) => {
  const { item, field, value } = payload

  const baseQuantities = {
    available_quantity: item.quantities.available,
    reserved_quantity: item.quantities.reserved,
    damaged_quantity: item.quantities.damaged,
    stolen_quantity: item.quantities.stolen,
    expired_quantity: item.quantities.expired,
  }

  if (field === 'available') baseQuantities.available_quantity = value
  if (field === 'reserved') baseQuantities.reserved_quantity = value
  if (field === 'damaged') baseQuantities.damaged_quantity = value
  if (field === 'stolen') baseQuantities.stolen_quantity = value
  if (field === 'expired') baseQuantities.expired_quantity = value

  if (!item.stock) {
    const createResult = await inventoryStore.createInventoryStock({
      inventory_item_id: item.id,
      ...baseQuantities,
    })

    if (!createResult.success) {
      handleApiFailure(createResult, createResult.error ?? 'Failed to create inventory stock.')
      return
    }
  } else {
    const updateResult = await inventoryStore.updateInventoryStock({
      id: item.stock.id,
      patch: baseQuantities,
    })

    if (!updateResult.success) {
      handleApiFailure(updateResult, updateResult.error ?? 'Failed to update inventory stock.')
      return
    }
  }

  await fetchInventoryItems()
}

const onDeleteItem = (item: InventoryItemWithStock) => {
  $q.dialog({
    title: 'Delete Inventory Item',
    message: `Are you sure you want to delete "${item.name}"? This will also delete its stock record.`,
    cancel: true,
    persistent: true,
    ok: {
      label: 'Delete',
      color: 'negative',
      unelevated: true,
    },
  }).onOk(() => {
    void (async () => {
      const result = await inventoryStore.deleteInventoryItem({ id: item.id })

      if (!result.success) {
        handleApiFailure(result, result.error ?? 'Failed to delete inventory item.')
        return
      }

      await fetchInventoryItems()
    })()
  })
}

const onSaveDate = async (payload: {
  item: InventoryItemWithStock
  field: 'manufacturing_date' | 'expire_date'
  value: string | null
}) => {
  const result = await inventoryStore.updateInventoryItem({
    id: payload.item.id,
    patch: {
      [payload.field]: payload.value,
    },
  })

  if (!result.success) {
    handleApiFailure(result, result.error ?? 'Failed to update date.')
    return
  }

  await fetchInventoryItems()
}

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
