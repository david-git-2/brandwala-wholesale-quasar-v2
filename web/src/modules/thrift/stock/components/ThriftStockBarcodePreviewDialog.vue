<script setup lang="ts">
import BarcodeRenderer from 'src/modules/thrift/barcode/components/BarcodeRenderer.vue';

defineProps<{
  modelValue: boolean;
  barcodeValue: string;
  stockLabel: string;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'copy'): void;
}>();
</script>

<template>
  <q-dialog :model-value="modelValue" @update:model-value="(val) => emit('update:modelValue', val)">
    <q-card style="min-width: 320px; text-align: center; border-radius: 14px">
      <q-card-section class="bg-grey-2 q-py-xs text-right">
        <q-btn flat round dense icon="ph ph-x" v-close-popup />
      </q-card-section>

      <q-card-section class="q-pa-lg">
        <div class="text-overline text-grey-7 q-mb-xs">THRIFT STOCK BARCODE</div>
        <div v-if="stockLabel" class="text-caption text-grey-7 q-mb-xs">
          {{ stockLabel }}
        </div>
        <div class="q-mb-md text-weight-bold text-subtitle1">{{ barcodeValue }}</div>

        <div class="q-my-md q-px-md row justify-center">
          <div class="barcode-preview-frame">
            <BarcodeRenderer
              v-if="barcodeValue"
              :value="barcodeValue"
              :display-value="false"
              :height="48"
            />
          </div>
        </div>
      </q-card-section>

      <q-card-actions align="center" class="q-pb-md">
        <q-btn
          color="primary"
          no-caps
          icon="ph ph-copy"
          label="Copy barcode"
          class="pill-btn"
          @click="emit('copy')"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<style scoped>
.pill-btn {
  border-radius: 8px;
}

.barcode-preview-frame {
  width: 100%;
  max-width: 280px;
  border: 1px solid #e0e0e0;
  padding: 12px;
  border-radius: 8px;
  background: #fff;
}
</style>
