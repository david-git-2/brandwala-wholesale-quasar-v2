<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="$emit('update:modelValue', $event)">
    <q-card style="min-width: 350px; border-radius: 12px">
      <q-card-section class="row items-center">
        <q-avatar icon="ph ph-warning" color="warning" text-color="white" />
        <span class="q-ml-sm text-subtitle1 text-weight-bold">Delete Role</span>
      </q-card-section>

      <q-card-section class="q-pt-none">
        Are you sure you want to delete the role <strong>{{ roleName }}</strong>? This action cannot be undone.
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md">
        <q-btn flat no-caps label="Cancel" v-close-popup />
        <q-btn
          color="negative"
          unelevated
          class="pill-btn"
          no-caps
          label="Delete"
          :loading="deleting"
          @click="$emit('confirm')"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
defineProps<{
  modelValue: boolean;
  roleName?: string | undefined;
  deleting: boolean;
}>();

defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'confirm'): void;
}>();
</script>
