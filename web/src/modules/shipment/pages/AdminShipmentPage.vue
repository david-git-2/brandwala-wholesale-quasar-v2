<template>
  <q-page padding>
    <div class="text-h5">Shipment Management</div>
    <div class="row justify-end q-mb-md">
      <q-btn label="Create Shipment" color="primary" @click="openCreate" />
    </div>
    <CreateShipmentDialog v-model="showDialog" :initialData="selectedShipment" @submit="onSubmit" />
    <PageInitialLoader v-if="shipmentStore.loading" />
    <q-card v-else flat bordered>
      <q-markup-table flat>
        <thead>
          <tr>
            <th class="text-left" style="width: 80px">ID</th>
            <th class="text-left">Name</th>
            <th class="text-left" style="width: 220px">Status</th>
            <th class="text-right" style="width: 90px">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="shipment in shipmentStore.shipments"
            :key="shipment.id"
            class="cursor-pointer"
            @click="onSelectShipment(shipment)"
          >
            <td>#{{ shipment.id }}</td>
            <td>{{ shipment.name }}</td>
            <td>
              <q-chip
                dense
                square
                :color="statusChipColor(shipment.status)"
                text-color="white"
                class="shipment-status-chip"
              >
                {{ shipment.status }}
              </q-chip>
            </td>
            <td class="text-right">
              <q-btn flat round dense icon="more_vert" aria-label="Shipment actions" @click.stop>
                <q-menu auto-close>
                  <q-list dense style="min-width: 120px">
                    <q-item clickable v-ripple @click="onShipmentEdit(shipment)">
                      <q-item-section>Edit</q-item-section>
                    </q-item>
                    <q-item clickable v-ripple @click="onShipmentCopy(shipment)">
                      <q-item-section>Copy</q-item-section>
                    </q-item>
                    <q-item clickable v-ripple @click="onShipmentDelete(shipment)">
                      <q-item-section class="text-negative">Delete</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </td>
          </tr>
          <tr v-if="!shipmentStore.shipments.length">
            <td colspan="4" class="text-center text-grey-6 q-pa-md">No shipments found</td>
          </tr>
        </tbody>
      </q-markup-table>
    </q-card>

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

const statusChipColor = (status: string | null | undefined) => {
  if (status === 'Draft') return 'grey-7'
  if (status === 'Order Placed') return 'indigo'
  if (status === 'Proforma Generated') return 'purple-7'
  if (status === 'Payment Done') return 'teal'
  if (status === 'Delivery Date Received') return 'cyan-8'
  if (status === 'Uk Warehouse Delivery Received') return 'blue'
  if (status === 'Air Shipment Date Set') return 'orange-8'
  if (status === 'Airport Arrival') return 'deep-orange'
  if (status === 'Airport Released') return 'brown-7'
  if (status === 'Warehouse Received') return 'positive'
  if (status === 'Added to Inventory') return 'green-8'
  return 'primary'
}

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

const onShipmentCopy = async (shipment: Shipment) => {
  await shipmentStore.copyShipment({ id: shipment.id })
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

<style scoped>
.shipment-status-chip {
  border-radius: 0 !important;
}
</style>
