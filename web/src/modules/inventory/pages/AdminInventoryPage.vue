<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-h5">Shipment</div>
      <q-btn color="primary" label="Add Item" @click="openAddDialog" />
    </div>

    <InventoryItemDialog v-model="isAddDialogOpen" @save="onSaveItem" />
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { handleApiFailure } from 'src/utils/appFeedback'
import InventoryItemDialog from '../components/InventoryItemDialog.vue'
import { useInventoryStore } from '../stores/inventoryStore'
import type { CreateInventoryItemInput } from '../types'

const authStore = useAuthStore()
const inventoryStore = useInventoryStore()

const isAddDialogOpen = ref(false)

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
  }
}

onMounted(() => {
  const tenantId = authStore.tenantId

  if (!tenantId) {
    handleApiFailure({ success: false, error: 'Tenant is not selected.' }, 'Tenant is not selected.')
    return
  }

  void inventoryStore.fetchInventoryItems({
    tenant_id: tenantId,
    page: 1,
    pageSize: 20,
    sortBy: 'id',
    sortOrder: 'desc',
  })
})
</script>
