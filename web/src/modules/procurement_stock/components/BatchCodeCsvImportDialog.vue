<template>
  <q-dialog
    :model-value="modelValue"
    persistent
    @update:model-value="emit('update:modelValue', $event)"
  >
    <q-card style="width: 520px; max-width: 92vw; border-radius: 12px">
      <q-card-section class="row items-center q-pb-none">
        <q-avatar color="primary" text-color="white" icon="ph ph-upload-simple" size="32px" />
        <div class="q-ml-sm col">
          <div class="text-subtitle1 text-weight-bold">Import CSV</div>
          <div class="text-caption text-grey-7">
            Download the sample, add your lines, then choose that file. New lines are added below
            what is already on the list.
          </div>
        </div>
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-gutter-y-md q-pt-sm">
        <q-btn
          outline
          no-caps
          color="primary"
          icon="ph ph-download-simple"
          label="Download sample CSV"
          class="full-width"
          style="border-radius: 8px"
          @click="downloadBatchCodeSampleCsv"
        />

        <q-file
          v-model="selectedFile"
          label="Choose CSV file"
          dense
          outlined
          clearable
          accept=".csv,text/csv"
          @update:model-value="onFileChange"
        >
          <template #prepend>
            <q-icon name="ph ph-file-csv" />
          </template>
        </q-file>
      </q-card-section>

      <q-card-actions align="right" class="q-px-md q-pb-md">
        <q-btn flat no-caps label="Cancel" v-close-popup />
        <q-btn
          color="primary"
          unelevated
          no-caps
          label="Import"
          style="border-radius: 8px"
          :loading="saving"
          :disable="!selectedFile"
          @click="onImport"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import { showErrorNotification } from 'src/utils/appFeedback';
import type { BatchCodePasteRow } from '../repositories/batchCodeRepository';
import { downloadBatchCodeSampleCsv, parseBatchCodeCsv } from '../utils/batchCodeCsv';

const props = defineProps<{
  modelValue: boolean;
  saving?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  apply: [rows: BatchCodePasteRow[]];
}>();

const selectedFile = ref<File | null>(null);

watch(
  () => props.modelValue,
  (open) => {
    if (open) selectedFile.value = null;
  },
);

const onFileChange = (file: File | null) => {
  selectedFile.value = file;
};

const onImport = async () => {
  const file = selectedFile.value;
  if (!file) return;

  try {
    const text = await file.text();
    const rows = parseBatchCodeCsv(text);
    emit('apply', rows);
  } catch (error: unknown) {
    showErrorNotification((error as Error).message || 'Could not read the CSV file.');
  }
};
</script>
