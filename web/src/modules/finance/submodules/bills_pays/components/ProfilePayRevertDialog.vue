<template>
  <q-dialog :model-value="modelValue" @update:model-value="$emit('update:modelValue', $event)">
    <q-card style="min-width: 320px">
      <q-card-section class="text-weight-bold">Revert transaction?</q-card-section>
      <q-card-section class="text-body2 text-grey-8">
        The original stays on the list as reverted. A reversal pay will undo the cash movement.
      </q-card-section>
      <q-card-section>
        <q-input
          v-model="reason"
          outlined
          dense
          label="Reason"
          type="textarea"
          autogrow
          :rules="[(v) => !!String(v ?? '').trim() || 'Reason is required']"
        />
      </q-card-section>
      <q-card-actions align="right">
        <q-btn flat no-caps label="Cancel" @click="onCancel" />
        <TfBtn
          variant="danger-trigger"
          size="sm"
          label="Revert"
          :loading="loading"
          :disable="!reason.trim()"
          @click="onConfirm"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';

const props = defineProps<{
  modelValue: boolean;
  loading?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  confirm: [reason: string];
}>();

const reason = ref('');

watch(
  () => props.modelValue,
  (open) => {
    if (open) reason.value = '';
  },
);

const onCancel = () => {
  emit('update:modelValue', false);
};

const onConfirm = () => {
  const trimmed = reason.value.trim();
  if (!trimmed) return;
  emit('confirm', trimmed);
};
</script>
