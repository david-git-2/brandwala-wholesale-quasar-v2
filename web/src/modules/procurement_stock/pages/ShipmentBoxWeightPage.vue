<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <ShipmentBoxWeightGrid :shipment-id="shipmentId" />
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import ShipmentBoxWeightGrid from '../components/ShipmentBoxWeightGrid.vue';

const route = useRoute();
const shipmentId = computed(() => Number(route.params.id));
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  overflow: hidden;
}
</style>
