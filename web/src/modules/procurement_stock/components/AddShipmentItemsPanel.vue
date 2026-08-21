<template>
  <div
    class="add-items-panel column no-wrap"
    :class="{ 'add-items-panel--drawer': layout === 'drawer' }"
  >
    <q-tabs
      v-model="activeTab"
      dense
      class="text-grey"
      active-color="primary"
      indicator-color="primary"
      align="justify"
      narrow-indicator
    >
      <q-tab name="catalog" icon="ph ph-squares-four" label="Catalog Products" />
      <q-tab name="children" icon="ph ph-arrow-down-left" label="Pull from Children">
        <q-badge v-if="childCount > 0" color="orange-9" floating rounded>
          {{ childCount }}
        </q-badge>
      </q-tab>
    </q-tabs>

    <AddShipmentCatalogTab
      v-if="activeTab === 'catalog'"
      :shipment-id="shipmentId"
      :initial-section-id="initialSectionId"
      @done="$emit('saved')"
    />

    <AddShipmentChildLinesTab
      v-else-if="activeTab === 'children'"
      :shipment-id="shipmentId"
      @done="$emit('saved')"
      @count-updated="(c) => (childCount = c)"
    />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import AddShipmentCatalogTab from './AddShipmentCatalogTab.vue';
import AddShipmentChildLinesTab from './AddShipmentChildLinesTab.vue';

withDefaults(
  defineProps<{
    shipmentId: number;
    initialSectionId?: number | null | undefined;
    layout?: 'drawer' | 'page';
    showCancel?: boolean;
  }>(),
  {
    initialSectionId: null,
    layout: 'drawer',
    showCancel: true,
  },
);

defineEmits<{
  saved: [];
  cancel: [];
}>();

const activeTab = ref<'catalog' | 'children'>('catalog');
const childCount = ref(0);
</script>

<style scoped>
.add-items-panel {
  flex: 1;
  min-height: 0;
  background: transparent;
}

.add-items-panel--drawer {
  width: 100%;
}

.add-items-panel:not(.add-items-panel--drawer) {
  min-height: 70vh;
}
</style>
