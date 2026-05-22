<template>
  <q-page class="q-pa-md">
    <div class="text-h5 text-weight-bold q-mb-md">Investor Shipment</div>

    <q-markup-table flat bordered wrap-cells>
      <thead>
        <tr>
          <th class="text-left">SL</th>
          <th class="text-left">Shipment ID</th>
          <th class="text-left">Name</th>
          <th class="text-left">Status</th>
          <th class="text-left">Created At</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="!shipmentStore.shipments.length && !shipmentStore.loading">
          <td colspan="5" class="text-center text-grey-7">No shipments found.</td>
        </tr>
        <tr
          v-for="(shipment, index) in shipmentStore.shipments"
          :key="shipment.id"
          class="cursor-pointer"
          @click="onSelectShipment(shipment.id)"
        >
          <td>{{ index + 1 }}</td>
          <td>#{{ shipment.tenant_shipment_id }}</td>
          <td>{{ shipment.name ?? '-' }}</td>
          <td>{{ shipment.status ?? '-' }}</td>
          <td>{{ shipment.created_at ?? '-' }}</td>
        </tr>
      </tbody>
    </q-markup-table>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore'

const authStore = useAuthStore()
const shipmentStore = useShipmentStore()
const router = useRouter()
const route = useRoute()

const loadShipments = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return
  await shipmentStore.fetchShipments(tenantId)
}

const onSelectShipment = async (shipmentId: number) => {
  await router.push({
    name: 'app-investor-shipment-details-page',
    params: {
      tenantSlug: route.params.tenantSlug,
      id: shipmentId,
    },
  })
}

onMounted(() => {
  void loadShipments()
})
</script>
