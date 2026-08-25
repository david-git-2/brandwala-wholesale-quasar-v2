<template>
  <q-btn flat dense icon="ph ph-dots-three-vertical" color="grey-8" :aria-label="$t('product_based_costing.more_workflow_actions')">
    <q-menu anchor="bottom end" self="top end" class="shadow-4">
      <q-list dense style="min-width: 200px" class="q-py-xs">
        <q-item v-close-popup clickable @click="emit('override-status')">
          <q-item-section avatar style="min-width: 28px">
            <q-icon name="ph ph-arrows-clockwise" color="grey-8" size="18px" />
          </q-item-section>
          <q-item-section class="text-weight-medium">
            {{ $t('product_based_costing.override_status') }}
          </q-item-section>
        </q-item>
      </q-list>
    </q-menu>
  </q-btn>
</template>

<script setup lang="ts">
const emit = defineEmits<{
  (e: 'override-status'): void;
}>();
</script>
