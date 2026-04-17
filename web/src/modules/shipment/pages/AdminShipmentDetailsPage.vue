<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <q-btn
        flat
        no-caps
        color="primary"
        icon="arrow_back"
        label="Back to Shipment"
        @click="onBack"
      />
    </div>

    <div class="text-h5 q-mb-md">
      #{{ shipmentStore.selectedShipment?.id }} {{ shipmentStore.selectedShipment?.name }}
    </div>

    <q-banner v-if="shipmentStore.loading" class="bg-grey-2 text-grey-8 q-mb-md">
      Loading shipment details...
    </q-banner>

    <q-banner v-if="shipmentStore.error" class="bg-red-1 text-negative q-mb-md">
      {{ shipmentStore.error }}
    </q-banner>

<div>
  <q-btn color="primary" label="Add Item From Order" @click="onClick" />
</div>


  </q-page>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useShipmentStore } from '../stores/shipmentStore'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const shipmentStore = useShipmentStore()

const onBack = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/shipment`)
}

const onClick = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  const shipmentId = Number(route.params.id)
  await router.push(`${tenantPrefix}/app/shipment/${shipmentId}/orders`)
}

onMounted(async () => {
  const shipmentId = Number(route.params.id)

  if (!Number.isFinite(shipmentId) || shipmentId <= 0) {
    return
  }

  await shipmentStore.fetchShipmentById(shipmentId)
})
</script>
