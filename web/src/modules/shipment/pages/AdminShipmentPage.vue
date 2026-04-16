<template>
  <q-page class="q-pa-md">
    <div class="text-h5 q-mb-md text-weight-bold">Shipment</div>

    <q-banner v-if="shipmentStore.error" class="bg-red-1 text-negative q-mb-md">
      {{ shipmentStore.error }}
    </q-banner>

    <q-banner v-if="shipmentStore.loading" class="bg-grey-2 text-grey-8 q-mb-md">
      Loading shipments...
    </q-banner>

    <q-card flat bordered>
      <q-card-section class="text-subtitle1">Shipments</q-card-section>
      <q-list separator>
        <q-item v-for="shipment in shipmentStore.shipments" :key="shipment.id">
          <q-item-section>
            <q-item-label>#{{ shipment.id }} {{ shipment.name }}</q-item-label>
            <q-item-label caption>
              Weight: {{ shipment.weight ?? 'N/A' }} | Received: {{ shipment.received_weight ?? 'N/A' }}
            </q-item-label>
          </q-item-section>
        </q-item>
        <q-item v-if="!shipmentStore.loading && !shipmentStore.shipments.length">
          <q-item-section>
            <q-item-label>No shipments found.</q-item-label>
          </q-item-section>
        </q-item>
      </q-list>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useShipmentStore } from '../stores/shipmentStore'

const authStore = useAuthStore()
const shipmentStore = useShipmentStore()

onMounted(async () => {
  if (!authStore.tenantId) {
    return
  }

  await shipmentStore.fetchShipments(authStore.tenantId)
})
</script>
