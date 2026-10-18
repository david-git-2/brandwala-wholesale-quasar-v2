<template>
  <q-dialog
    v-model="open"
    :position="dialogPosition"
    :persistent="persistent"
    @hide="onHide"
  >
    <q-card flat bordered class="tf-confirm-dialog">
      <q-card-section>
        <div class="tf-confirm-dialog__title">{{ title }}</div>
        <p class="q-mt-xs q-mb-none tf-confirm-dialog__msg">{{ message }}</p>
        <slot />
      </q-card-section>
      <q-card-actions align="right" class="q-px-md q-pb-sm">
        <TfBtn variant="tertiary" :label="cancelLabel" @click="onCancel" />
        <TfBtn
          :variant="confirmVariant"
          :label="confirmLabel"
          :loading="confirmLoading"
          @click="onConfirm"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useQuasar } from 'quasar';

import TfBtn from 'src/components/ui/TfBtn.vue';

const props = withDefaults(
  defineProps<{
    modelValue: boolean;
    title: string;
    message: string;
    destructive?: boolean;
    successConfirm?: boolean;
    persistent?: boolean;
    confirmLabel?: string;
    cancelLabel?: string;
    confirmLoading?: boolean;
  }>(),
  {
    destructive: false,
    successConfirm: false,
    persistent: true,
    confirmLabel: 'Confirm',
    cancelLabel: 'Cancel',
    confirmLoading: false,
  },
);

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  confirm: [];
  cancel: [];
}>();

const $q = useQuasar();

const open = computed({
  get: () => props.modelValue,
  set: (v: boolean) => emit('update:modelValue', v),
});

const dialogPosition = computed(() => ($q.screen.lt.sm ? 'bottom' : 'standard'));

const confirmVariant = computed(() => {
  if (props.destructive) return 'danger';
  if (props.successConfirm) return 'success';
  return 'primary';
});

function onConfirm() {
  emit('confirm');
}

function onCancel() {
  emit('cancel');
  open.value = false;
}

function onHide() {
  emit('update:modelValue', false);
}
</script>

<style scoped>
.tf-confirm-dialog {
  min-width: 320px;
  max-width: 440px;
  border-radius: var(--tf-radius-sm);
}
.tf-confirm-dialog__title {
  font-size: 15px;
  font-weight: 600;
  color: var(--tf-neutral-ink);
}
.tf-confirm-dialog__msg {
  font-size: 13px;
  color: var(--tf-neutral-muted);
}
</style>
