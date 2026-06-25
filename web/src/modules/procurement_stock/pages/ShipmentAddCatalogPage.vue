<template>
  <q-page class="bw-page">
    <div class="bw-page__stack">
      <!-- Page Header -->
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col">
          <AppPageHeader
            eyebrow="Procurement & Stock"
            title="Add Items"
            :subtitle="shipmentSubtitle"
          />
        </div>
        <div class="col-auto">
          <q-btn
            flat
            color="primary"
            icon="arrow_back"
            label="Back to Shipment"
            no-caps
            @click="goBack"
          />
        </div>
      </div>

      <AddShipmentItemsPanel
        :shipment-id="shipmentId"
        layout="page"
        @saved="goBack"
        @cancel="goBack"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useGlobalShipmentStore } from '../stores/globalShipmentStore'
import AddShipmentItemsPanel from '../components/AddShipmentItemsPanel.vue'
import AppPageHeader from 'src/components/ui/AppPageHeader.vue'

const route = useRoute()
const router = useRouter()
const shipmentStore = useGlobalShipmentStore()
const shipmentId = Number(route.params.id)

const shipmentSubtitle = computed(() => {
  const name = shipmentStore.currentShipment?.name
  return name ? `Shipment: ${name}` : 'Add products to shipment'
})

const goBack = () => {
  void router.push({
    name: 'app-procurement-shipment-details',
    params: { id: shipmentId, tenantSlug: route.params.tenantSlug },
  })
}

onMounted(() => {
  if (!Number.isNaN(shipmentId)) {
    void shipmentStore.fetchShipmentDetails(shipmentId)
  }
})
</script>

<style scoped>
</style>
