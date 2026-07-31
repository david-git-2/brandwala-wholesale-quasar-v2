<script setup lang="ts">
defineProps<{
  selectedCount: number;
}>();

defineEmits<{
  (e: 'clear-selection'): void;
  (e: 'confirm-bulk-delete'): void;
}>();
</script>

<template>
  <q-card
    v-if="selectedCount > 0"
    flat
    class="floating-surface shadow-1 bulk-selection-bar"
  >
    <q-card-section class="row items-center q-col-gutter-sm q-py-sm">
      <div class="col text-body2 text-weight-medium">
        {{ selectedCount }} item{{ selectedCount === 1 ? '' : 's' }} selected
      </div>
      <div class="col-auto row q-gutter-sm">
        <q-btn flat no-caps color="grey-8" label="Clear" @click="$emit('clear-selection')" />
        <q-btn
          color="negative"
          no-caps
          icon="ph ph-trash"
          label="Delete selected"
          @click="$emit('confirm-bulk-delete')"
        />
      </div>
    </q-card-section>
  </q-card>
</template>

<style scoped>
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.bulk-selection-bar {
  border-color: rgba(220, 38, 38, 0.18);
  background: rgba(254, 242, 242, 0.92);
}
</style>
