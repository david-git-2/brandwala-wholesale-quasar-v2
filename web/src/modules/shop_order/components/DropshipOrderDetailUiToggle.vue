<script setup lang="ts">
import { useDropshipOrderDetailUiToggle } from '../composables/useDropshipOrderDetailUiToggle';

const { isV2, toggleUi } = useDropshipOrderDetailUiToggle();
</script>

<template>
  <q-banner dense rounded class="dropship-detail-ui-toggle bg-amber-1 text-grey-9">
    <template #avatar>
      <q-icon name="ph ph-flask" color="amber-9" />
    </template>
    <span class="text-caption">
      {{ isV2 ? 'New dropship detail UI (draft)' : 'Classic dropship detail UI' }}
    </span>
    <template #action>
      <q-btn
        flat
        dense
        no-caps
        color="amber-10"
        class="text-weight-bold"
        :label="isV2 ? 'Switch to classic' : 'Try new UI'"
        @click="toggleUi"
      />
    </template>
  </q-banner>
</template>

<style scoped>
.dropship-detail-ui-toggle {
  border: 1px solid rgba(245, 158, 11, 0.35);
}
</style>
