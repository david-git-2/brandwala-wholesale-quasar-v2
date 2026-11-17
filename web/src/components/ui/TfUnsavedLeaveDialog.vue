<template>
  <q-dialog ref="dialogRef" persistent @hide="onDialogHide">
    <q-card flat bordered class="tf-unsaved-leave-dialog">
      <q-card-section>
        <div class="tf-unsaved-leave-dialog__title">{{ title }}</div>
        <p class="q-mt-xs q-mb-none tf-unsaved-leave-dialog__msg">{{ message }}</p>
      </q-card-section>
      <q-card-actions vertical class="q-px-md q-pb-md q-gutter-y-sm">
        <TfBtn variant="primary" label="Save" class="full-width" @click="onSave" />
        <TfBtn variant="danger" label="Discard changes" class="full-width" @click="onDiscard" />
        <TfBtn variant="tertiary" label="Continue editing" class="full-width" @click="onStay" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { useDialogPluginComponent } from 'quasar';
import TfBtn from 'src/components/ui/TfBtn.vue';

export type UnsavedLeaveChoice = 'save' | 'discard' | 'stay';

defineEmits([...useDialogPluginComponent.emits]);

withDefaults(
  defineProps<{
    title?: string;
    message?: string;
  }>(),
  {
    title: 'Unsaved changes',
    message: 'You have unsaved changes. Save before leaving, or discard them.',
  },
);

const { dialogRef, onDialogHide, onDialogOK, onDialogCancel } = useDialogPluginComponent();

const onSave = () => onDialogOK('save' satisfies UnsavedLeaveChoice);
const onDiscard = () => onDialogOK('discard' satisfies UnsavedLeaveChoice);
const onStay = () => onDialogCancel();
</script>

<style scoped>
.tf-unsaved-leave-dialog {
  min-width: 320px;
  max-width: 400px;
  border-radius: var(--tf-radius-sm);
}
.tf-unsaved-leave-dialog__title {
  font-size: 15px;
  font-weight: 600;
  color: var(--tf-neutral-ink);
}
.tf-unsaved-leave-dialog__msg {
  font-size: 13px;
  color: var(--tf-neutral-muted);
}
</style>