<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-h5">Shipment</div>
      <q-btn color="primary" label="Add Item" @click="openAddDialog" />
    </div>

    <div class="row q-col-gutter-md q-mb-md">
      <div class="col-12 col-md-5">
        <q-input
          v-model="searchText"
          outlined
          dense
          label="Search by name"
          clearable
          @keyup.enter="() => { page = 1; void fetchInventoryItems() }"
        />
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
          @click="() => { searchText = ''; shipmentIdFilter = null; page = 1; void fetchInventoryItems() }"
        />
      </div>
    </div>

    <InventoryItemDialog v-model="isAddDialogOpen" @save="onSaveItem" />
    <InventoryCard
      :items="inventoryStore.items"
      @save-quantity="onSaveQuantity"
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
import { handleApiFailure } from 'src/utils/appFeedback'
import InventoryCard from '../components/InventoryCard.vue'
import InventoryItemDialog from '../components/InventoryItemDialog.vue'
import { useInventoryStore } from '../stores/inventoryStore'
import type { CreateInventoryItemInput, InventoryItemWithStock } from '../types'

const authStore = useAuthStore()
const inventoryStore = useInventoryStore()
const shipmentStore = useShipmentStore()
const $q = useQuasar()

const isAddDialogOpen = ref(false)
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

const fetchInventoryItems = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) {
    handleApiFailure({ success: false, error: 'Tenant is not selected.' }, 'Tenant is not selected.')
    return
  }

  const filters: Record<string, unknown> = {}
  if (searchText.value.trim()) {
    filters.name = searchText.value.trim()
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

  const result = await inventoryStore.createInventoryItem({
    tenant_id: tenantId,
    source_type: 'manual',
    source_id: null,
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

  await fetchInventoryItems()
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
