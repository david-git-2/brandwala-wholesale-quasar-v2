<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="$emit('update:modelValue', $event)">
    <q-card style="min-width: 350px; border-radius: 12px">
      <q-card-section class="row items-center">
        <q-avatar icon="ph ph-warning" color="warning" text-color="white" />
        <span class="q-ml-sm text-subtitle1 text-weight-bold">Delete Customer Group</span>
      </q-card-section>

      <q-card-section class="q-pt-none">
        Are you sure you want to delete customer group
        <strong>{{ groupName }}</strong>? This will delete all members inside this group.
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md">
        <q-btn flat no-caps label="Cancel" v-close-popup />
        <q-btn
          color="negative"
          unelevated
          class="pill-btn"
          no-caps
          label="Delete"
          @click="$emit('confirm')"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
defineProps<{
  modelValue: boolean;
  groupName?: string | undefined;
}>();

defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'confirm'): void;
}>();
</script>
