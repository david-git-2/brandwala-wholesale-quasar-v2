<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <q-btn
        flat
        no-caps
        color="primary"
        icon="arrow_back"
        label="Back to Shipment Details"
        @click="onBack"
      />
    </div>

    <div class="text-h5 q-mb-md">
      Shipment #{{ shipmentId }} Order List
    </div>

    <q-banner class="bg-grey-2 text-grey-8">
      This is the shipment module order list page.
    </q-banner>

<div v-for="value in orderStore.items" :key="value.id">
<q-card class="my-card"  flat>
  <q-card-section horizontal class="row justify-between">
  <div>{{ value.name }}</div>
  <div><q-btn color="primary"  label="Add to Shipment" @click="onAddToShipment" /></div>
    </q-card-section>

</q-card>
</div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useOrderStore } from 'src/modules/order/stores/orderStore'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const orderStore = useOrderStore()

const shipmentId = computed(() => Number(route.params.id) || 0)

const onBack = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/shipment/${shipmentId.value}`)
}
const onAddToShipment=()=>{
  console.log('add to shipment')
}
onMounted(() => {
  void orderStore.fetchOrders({ shipment_id: null, status: 'ordered' })
})
</script>
