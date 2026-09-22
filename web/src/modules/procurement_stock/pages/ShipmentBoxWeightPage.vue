<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="shrink-0 row items-center justify-end q-mb-sm q-px-xs">
      <q-btn
        color="primary"
        icon="ph ph-plus"
        label="Add box"
        class="rounded-sq-btn text-weight-bold"
        unelevated
        no-caps
        @click="onAddBox"
      />
    </div>
    <ShipmentBoxWeightGrid ref="gridRef" :shipment-id="shipmentId" />
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import ShipmentBoxWeightGrid from '../components/ShipmentBoxWeightGrid.vue';

const route = useRoute();
const shipmentId = computed(() => Number(route.params.id));

const gridRef = ref<InstanceType<typeof ShipmentBoxWeightGrid> | null>(null);

const onAddBox = () => {
  gridRef.value?.openAddDialog();
};
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  overflow: hidden;
}
</style>
