<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" persistent>
    <q-card style="width: 640px; max-width: 95vw" class="floating-surface shadow-2">
      <q-card-section class="row items-center justify-between q-pb-sm">
        <div>
          <div class="text-h6 text-weight-bold">Marketing Tag Layout</div>
          <div class="text-caption text-grey-8">{{ shipmentName }}</div>
        </div>
        <q-btn flat round dense icon="close" v-close-popup />
      </q-card-section>
      <q-separator />

      <q-card-section class="q-pt-md">
        <div class="row q-col-gutter-md">
          <div class="col-12 col-md-6 column q-gutter-y-sm">
            <q-input
              v-model="form.brand_name"
              outlined
              dense
              label="Shop Brand Name (optional override)"
              class="soft-input"
            />
            <q-checkbox v-model="form.show_logo" label="Show BAS Logo" dense />
            <q-checkbox v-model="form.show_brand_name" label="Show Brand Name" dense />
            <q-checkbox v-model="form.show_listed_sell" label="Show Listed Sell Price" dense />
            <q-checkbox
              v-model="form.show_core_sizes"
              label="Show Size (core measurements)"
              dense
            />
            <q-checkbox
              v-model="form.show_additional_sizes"
              label="Show Additional measurements"
              dense
            />
            <q-checkbox v-model="form.show_barcode_text" label="Show Barcode Text" dense />
          </div>
          <div class="col-12 col-md-6 flex justify-center items-center">
            <div style="width: 58mm">
              <div class="text-caption text-weight-bold text-grey-7 q-mb-xs text-center">
                Preview
              </div>
              <StockMarketingTag
                :stock="mockStock"
                :tag-config="form"
                listed-sell-formatted="৳150"
              />
            </div>
          </div>
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-px-md q-pb-md">
        <q-btn flat label="Cancel" color="grey" v-close-popup :disable="saving" />
        <q-btn
          unelevated
          label="Save"
          color="primary"
          class="pill-btn"
          :loading="saving"
          @click="onSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useDialogPluginComponent, useQuasar } from 'quasar';
import { thriftShipmentRepository } from '../repositories/thriftShipmentRepository';
import StockMarketingTag from '../../stock/components/StockMarketingTag.vue';
import type { ThriftMarketingTagConfig } from '../types/marketingTag';
import { resolveMarketingTagConfig } from '../utils/defaultMarketingTagConfig';
import type { ThriftStock } from '../../stock/types';

const props = defineProps<{
  shipmentId: number;
  shipmentName: string;
  initialConfig?: Partial<ThriftMarketingTagConfig> | null;
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();
const $q = useQuasar();

const saving = ref(false);
const form = ref<ThriftMarketingTagConfig>(resolveMarketingTagConfig(props.initialConfig));

const mockStock: ThriftStock = {
  id: 0,
  tenant_id: 0,
  shipment_id: props.shipmentId,
  name: 'Sample Item',
  brand_name: 'Zara',
  category_id: null,
  type_id: null,
  section: null,
  color: '',
  size: 'M',
  condition: null,
  barcode: 'TH-00001',
  stock_type: 'SINGLE',
  quantity: 1,
  status: 'AVAILABLE',
  inserted_by: '',
  created_at: '',
  updated_at: '',
  measurements: {
    stock_id: 0,
    tenant_id: 0,
    bust_in: 34,
    waist_in: 28,
    hips_in: 36,
    length_in: 42,
    shoulder_width_in: 16,
    sleeve_length_in: 24,
    fabric_stretch: 'medium',
  },
};

async function onSave() {
  saving.value = true;
  try {
    const updated = await thriftShipmentRepository.updateShipment(props.shipmentId, {
      marketing_tag_config: form.value,
    });
    onDialogOK(updated);
    $q.notify({ type: 'positive', message: 'Tag layout saved' });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Save failed' });
  } finally {
    saving.value = false;
  }
}
</script>

<style scoped>
.pill-btn {
  border-radius: 999px;
}
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
}
</style>
