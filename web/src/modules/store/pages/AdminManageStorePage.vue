<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-h6">Manage Store</div>
      <q-btn label="Create Store" color="primary" @click="openCreate" />
    </div>

    <q-table
      flat
      bordered
      row-key="id"
      :rows="storeStore.items"
      :columns="columns"
      :loading="storeStore.loading"
    >
      <template #body-cell-actions="props">
        <q-td align="right">
          <q-btn
            flat
            round
            dense
            icon="edit"
            color="primary"
            @click="openEdit(props.row)"
          />
          <q-btn
            flat
            round
            dense
            icon="delete"
            color="negative"
            @click="openDelete(props.row)"
          />
        </q-td>
      </template>
    </q-table>

    <StoreDialog
      :open="dialogOpen"
      :data="selectedStore"
      @close="dialogOpen = false"
      @save="handleSave"
    />

    <q-dialog v-model="deleteDialogOpen">
      <q-card style="min-width: 360px; max-width: 90vw">
        <q-card-section>
          <div class="text-h6">Delete Store</div>
        </q-card-section>

        <q-card-section>
          Are you sure you want to delete
          <strong>{{ selectedStore?.name }}</strong
          >?
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="deleteDialogOpen = false" />
          <q-btn
            color="negative"
            label="Delete"
            :loading="deleting"
            @click="handleDelete"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import StoreDialog from '../components/StoreDialog.vue'
import { useStoreStore } from '../stores/storeStore'
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import { useQuasar, type QTableColumn } from 'quasar'

type StoreItem = {
  id: number
  name: string
  vendor_code: string
  tenant_id: number
  created_at: string
  updated_at: string
}

type StoreFormData = {
  id?: number | string
  name: string
  vendor_code: string
}

const $q = useQuasar()

const tenantStore = useTenantStore()
const vendorStore = useVendorStore()
const storeStore = useStoreStore()

const dialogOpen = ref(false)
const deleteDialogOpen = ref(false)
const deleting = ref(false)
const selectedStore = ref<StoreItem | null>(null)

const columns: QTableColumn<StoreItem>[] = [
  {
    name: 'id',
    label: 'ID',
    field: 'id',
    align: 'left',
    sortable: true,
  },
  {
    name: 'name',
    label: 'Name',
    field: 'name',
    align: 'left',
    sortable: true,
  },
  {
    name: 'vendor_code',
    label: 'Vendor Code',
    field: 'vendor_code',
    align: 'left',
    sortable: true,
  },

  {
    name: 'actions',
    label: 'Actions',
    field: 'actions',
    align: 'right',
  },
]

const openCreate = () => {
  selectedStore.value = null
  dialogOpen.value = true
}

const openEdit = (row: StoreItem) => {
  selectedStore.value = { ...row }
  dialogOpen.value = true
}

const openDelete = (row: StoreItem) => {
  selectedStore.value = { ...row }
  deleteDialogOpen.value = true
}

const handleSave = async (payload: StoreFormData) => {
  try {
    if (payload.id) {
      await storeStore.updateStore({
        id: Number(payload.id),
        name: payload.name,
        vendor_code: payload.vendor_code,
      })

      $q.notify({
        type: 'positive',
        message: 'Store updated successfully',
      })
    } else {
      await storeStore.createStore({
        name: payload.name,
        vendor_code: payload.vendor_code,
        tenant_id: tenantStore.selectedTenant?.id || 0,
      })

      $q.notify({
        type: 'positive',
        message: 'Store created successfully',
      })
    }

    dialogOpen.value = false
    await storeStore.fetchStoresAdmin(tenantStore.selectedTenant?.id || 0)
  } catch (error) {
    console.error(error)
    $q.notify({
      type: 'negative',
      message: 'Failed to save store',
    })
  }
}

const handleDelete = async () => {
  if (!selectedStore.value?.id) return

  try {
    deleting.value = true

    await storeStore.deleteStore({ id: selectedStore.value.id })

    $q.notify({
      type: 'positive',
      message: 'Store deleted successfully',
    })

    deleteDialogOpen.value = false
    selectedStore.value = null

    await storeStore.fetchStoresAdmin(tenantStore.selectedTenant?.id || 0)
  } catch (error) {
    console.error(error)
    $q.notify({
      type: 'negative',
      message: 'Failed to delete store',
    })
  } finally {
    deleting.value = false
  }
}

onMounted(async () => {
  await vendorStore.fetchVendors()
  await storeStore.fetchStoresAdmin(tenantStore.selectedTenant?.id || 0)
})
</script>
