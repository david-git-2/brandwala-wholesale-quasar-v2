<template>
  <FilterSidebar
    :model-value="modelValue"
    :title="isEdit ? 'Edit item' : 'Add item'"
    width="min(420px, 92vw)"
    :resizable="false"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <div class="text-caption text-grey-7 q-mb-sm">Product link and quantity</div>
    <div class="q-gutter-y-sm">
      <q-input
        v-model="url"
        outlined
        dense
        hide-bottom-space
        label="Product URL *"
        type="url"
        autofocus
        @keyup.enter="focusQty"
      />
      <q-input
        ref="qtyInputRef"
        v-model.number="neededQty"
        outlined
        dense
        hide-bottom-space
        type="number"
        min="1"
        step="1"
        label="Quantity *"
        @keyup.enter="submit"
      />
      <q-input
        v-model="description"
        outlined
        dense
        hide-bottom-space
        type="textarea"
        label="Description"
        :rows="8"
        class="pp-add-line-dialog__description"
      />
    </div>
    <template #footer>
      <div class="row justify-end q-gutter-sm">
        <TfBtn variant="tertiary" size="md" label="Cancel" @click="$emit('update:modelValue', false)" />
        <TfBtn
          variant="primary"
          size="md"
          :label="isEdit ? 'Save' : 'Add'"
          :loading="loading"
          :disable="!canSubmit"
          @click="submit"
        />
      </div>
    </template>
  </FilterSidebar>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type { QInput } from 'quasar';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import type { PpOrderLine } from '../../types/ppPurchaseRequest';

const props = defineProps<{
  modelValue: boolean;
  loading?: boolean;
  editLine?: PpOrderLine | null;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [payload: { url: string; needed_qty: number; description?: string; lineId?: number }];
}>();

const isEdit = computed(() => props.editLine != null);

const url = ref('');
const neededQty = ref<number | null>(null);
const description = ref('');
const qtyInputRef = ref<QInput | null>(null);

const populateFromEdit = () => {
  const line = props.editLine;
  if (line) {
    url.value = line.url;
    neededQty.value = Number(line.needed_qty);
    description.value = line.description?.trim() ?? '';
    return;
  }
  url.value = '';
  neededQty.value = null;
  description.value = '';
};

watch(
  () => [props.modelValue, props.editLine] as const,
  ([open]) => {
    if (open) populateFromEdit();
  },
);

const canSubmit = computed(() => {
  const qty = neededQty.value;
  return url.value.trim().length > 0 && qty != null && Number.isFinite(qty) && qty > 0;
});

const focusQty = () => {
  qtyInputRef.value?.focus();
};

const submit = () => {
  if (!canSubmit.value || neededQty.value == null) return;
  emit('submit', {
    url: url.value.trim(),
    needed_qty: neededQty.value,
    description: description.value.trim() || undefined,
    lineId: props.editLine?.id,
  });
};
</script>

<style scoped>
.pp-add-line-dialog__description :deep(textarea) {
  min-height: 160px;
  resize: vertical;
  line-height: 1.45;
}
</style>