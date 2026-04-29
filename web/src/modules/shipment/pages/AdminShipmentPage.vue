<template>
  <q-page padding>
    <div class="text-h5">Shipment Management</div>
    <div class="row justify-end q-mb-md">
      <q-btn label="Create Shipment" color="primary" @click="openCreate" />
    </div>
    <CreateShipmentDialog v-model="showDialog" :initialData="selectedShipment" @submit="onSubmit" />
    <PageInitialLoader v-if="shipmentStore.loading" />
    <ShipmentListCard
      v-else
      @edit="onShipmentEdit"
      @delete="onShipmentDelete"
      @select="onSelectShipment"
    />

    <q-dialog v-model="showDeleteDialog" persistent>
      <q-card style="min-width: 320px">
        <q-card-section class="text-h6">Delete Shipment</q-card-section>
        <q-card-section>
          Are you sure you want to delete
          <strong>{{ pendingDeleteShipment?.name ?? 'this shipment' }}</strong
          >?
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="closeDeleteDialog" />
          <q-btn
            color="negative"
            label="Delete"
            :loading="shipmentStore.saving"
            @click="confirmDeleteShipment"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import CreateShipmentDialog from '../components/ShipmentDialog.vue'
import { useShipmentStore } from '../stores/shipmentStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import ShipmentListCard from '../components/ShipmentListCard.vue'
import type { Shipment } from '../types'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'

const shipmentStore = useShipmentStore()
const tenantStore = useTenantStore()
const authStore = useAuthStore()
const router = useRouter()

const showDialog = ref(false)
const selectedShipment = ref<{ id?: number; name?: string } | null>(null)
const showDeleteDialog = ref(false)
const pendingDeleteShipment = ref<Shipment | null>(null)

const openCreate = () => {
  selectedShipment.value = null
  showDialog.value = true
}

const onSubmit = async (data: { name: string }) => {
  if (selectedShipment.value?.id) {
    console.log('Updating shipment with data:', data)
    await shipmentStore.updateShipment({
      id: selectedShipment.value.id,
      patch: {
        name: data.name,
      },
    })
  } else {
    console.log('Creating shipment with data:', data)
    await shipmentStore.createShipment({
      name: data.name,
      tenant_id: tenantStore.selectedTenant?.id ?? 1,
    })
  }
}

const onShipmentEdit = (shipment: (typeof shipmentStore.shipments)[number]) => {
  selectedShipment.value = {
    id: shipment.id,
    name: shipment.name,
  }
  showDialog.value = true
}

const onShipmentDelete = (shipment: Shipment) => {
  pendingDeleteShipment.value = shipment
  showDeleteDialog.value = true
}

const closeDeleteDialog = () => {
  pendingDeleteShipment.value = null
  showDeleteDialog.value = false
}

const confirmDeleteShipment = async () => {
  if (!pendingDeleteShipment.value) {
    return
  }

  const result = await shipmentStore.deleteShipment({
    id: pendingDeleteShipment.value.id,
  })

  if (result.success) {
    closeDeleteDialog()
  }
}

const onSelectShipment = async (shipment: Shipment) => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/shipment/${shipment.id}`)
}

onMounted(async () => {
  await shipmentStore.fetchShipments(tenantStore.selectedTenant?.id ?? 1)
})
</script>
