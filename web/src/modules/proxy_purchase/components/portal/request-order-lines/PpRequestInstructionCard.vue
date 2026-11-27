<template>
  <article class="pp-request-instruction-card row no-wrap items-start q-gutter-x-sm">
    <div class="col min-width-0">
      <div class="pp-request-instruction-card__label text-weight-medium">
        {{ label }}
      </div>
      <p class="pp-request-instruction-card__text q-mb-none">
        {{ instruction.description }}
      </p>
    </div>
    <div
      v-if="showActions"
      class="row no-wrap items-center shrink-0 q-gutter-x-xs"
    >
      <TfBtn
        variant="icon"
        icon="ph ph-pencil"
        aria-label="Edit instruction"
        @click="emit('edit', instruction.store)"
      />
      <TfBtn
        variant="icon"
        icon="ph ph-trash"
        color="negative"
        aria-label="Delete instruction"
        :loading="deleteLoading"
        @click="emit('delete', instruction.store)"
      />
    </div>
  </article>
</template>

<script setup lang="ts">
import TfBtn from 'src/components/ui/TfBtn.vue';
import type { PpBucketInstruction } from '../../../types/ppPurchaseRequest';
import { ppBucketInstructionStoreLabel } from '../../../utils/ppBucketInstructions';

const props = defineProps<{
  instruction: PpBucketInstruction;
  showActions?: boolean;
  deleteLoading?: boolean;
}>();

const emit = defineEmits<{
  edit: [store: string];
  delete: [store: string];
}>();

const label = ppBucketInstructionStoreLabel(props.instruction.store);
</script>

<style scoped>
.pp-request-instruction-card {
  border: 1px solid var(--tf-neutral-border);
  border-radius: 10px;
  background: var(--tf-neutral-surface);
  padding: 10px 12px;
}

.pp-request-instruction-card__label {
  font-size: 12px;
  color: var(--tf-neutral-muted);
  text-transform: uppercase;
  letter-spacing: 0.04em;
  margin-bottom: 4px;
}

.pp-request-instruction-card__text {
  font-size: 13px;
  font-weight: 600;
  line-height: 1.45;
  color: var(--tf-neutral-ink);
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  word-break: break-word;
}
</style>