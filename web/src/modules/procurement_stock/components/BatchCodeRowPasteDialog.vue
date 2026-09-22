<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card style="width: 520px; max-width: 92vw; border-radius: 12px">
      <q-card-section class="row items-center q-pb-none">
        <q-avatar color="primary" text-color="white" icon="ph ph-clipboard-text" size="32px" />
        <div class="q-ml-sm col" style="min-width: 0">
          <div class="text-subtitle1 text-weight-bold">Paste {{ fieldLabel }}</div>
          <div class="text-caption text-grey-7">
            One value per line · updates rows and adds new ones when needed
          </div>
        </div>
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-gutter-y-md">
        <q-select
          v-if="!fieldLocked"
          v-model="selectedField"
          :options="fieldOptions"
          label="Column"
          dense
          outlined
          emit-value
          map-options
        />

        <q-input
          v-model="pasteText"
          type="textarea"
          outlined
          autogrow
          :rows="10"
          label="Paste values (one per line)"
          placeholder="One value per line, e.g. CGOLD156"
          class="paste-textarea"
        />

        <div v-if="parsedLines.length" class="text-caption text-grey-7">
          {{ parsedLines.length }} line<span v-if="parsedLines.length !== 1">s</span>
          · {{ rowsToUpdate }} to update
          <span v-if="rowsToCreate > 0">
            · {{ rowsToCreate }} new row<span v-if="rowsToCreate !== 1">s</span>
          </span>
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-px-md q-pb-md">
        <q-btn flat no-caps label="Cancel" v-close-popup />
        <q-btn
          color="primary"
          unelevated
          no-caps
          label="Apply paste"
          style="border-radius: 8px"
          :loading="saving"
          :disable="parsedLines.length === 0"
          @click="onApply"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import {
  BATCH_CODE_FIELD_LABELS,
  BATCH_CODE_PASTE_FIELDS,
  parseBatchCodeColumnPaste,
  type BatchCodePasteField,
} from '../composables/useShipmentBatchCodeGrid';

const props = defineProps<{
  modelValue: boolean;
  startRowIndex: number;
  totalRows: number;
  saving?: boolean;
  initialField?: BatchCodePasteField;
  fieldLocked?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  apply: [payload: { field: BatchCodePasteField; lines: string[] }];
}>();

const pasteText = ref('');
const selectedField = ref<BatchCodePasteField>('product_code');

const fieldOptions = computed(() =>
  BATCH_CODE_PASTE_FIELDS.map((field) => ({
    label: BATCH_CODE_FIELD_LABELS[field],
    value: field,
  })),
);

const fieldLabel = computed(() => BATCH_CODE_FIELD_LABELS[selectedField.value]);

const parsedLines = computed(() => parseBatchCodeColumnPaste(pasteText.value));

const rowsToUpdate = computed(() => {
  if (parsedLines.value.length === 0) return 0;
  const existing = Math.max(0, props.totalRows - props.startRowIndex);
  return Math.min(parsedLines.value.length, existing);
});

const rowsToCreate = computed(() => {
  if (parsedLines.value.length === 0) return 0;
  const existing = Math.max(0, props.totalRows - props.startRowIndex);
  return Math.max(0, parsedLines.value.length - existing);
});

watch(
  () => props.modelValue,
  (open) => {
    if (!open) {
      pasteText.value = '';
      return;
    }
    selectedField.value = props.initialField ?? 'product_code';
  },
);

const onApply = () => {
  if (parsedLines.value.length === 0 || props.saving) return;
  emit('apply', {
    field: selectedField.value,
    lines: parsedLines.value,
  });
};
</script>

<style scoped>
.paste-textarea :deep(textarea) {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 13px;
  line-height: 1.45;
}
</style>
