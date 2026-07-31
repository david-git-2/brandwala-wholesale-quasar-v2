<script setup lang="ts">
import { computed } from 'vue';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import type { ThriftCurrency } from 'src/modules/thrift/currency/types';

interface ShipmentOption {
  id: number;
  name: string;
  purchase_currency_id: number;
  cost_currency_id: number;
}

interface BoxOption {
  id: number;
  name: string;
  shipment_id?: number | null;
}

interface QuickAddForm {
  shipment_id: number | null;
  box_id: number | null;
  barcode: string;
  brand_name: string;
  condition: string;
  product_weight: number;
  imagePreviewUrl: string;
  pendingBlob: Blob | null;
}

const props = defineProps<{
  modelValue: boolean;
  form: QuickAddForm;
  shipments: ShipmentOption[];
  quickAddFilteredBoxes: BoxOption[];
  conditionSelectOptions: Array<{ label: string; value: string }>;
  quickAddBarcodeLoading: boolean;
  quickAddPurchaseCurrency?: ThriftCurrency | undefined;
  defaultOriginUnitPrice: number;
  quickSubmitting: boolean;
  canSubmitQuickAdd: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'update:form', val: QuickAddForm): void;
  (e: 'quick-shipment-change'): void;
  (e: 'open-uploader'): void;
  (e: 'submit'): void;
  (e: 'hide'): void;
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val: boolean) => emit('update:modelValue', val),
});

function updateFormField<K extends keyof QuickAddForm>(key: K, val: QuickAddForm[K]) {
  emit('update:form', {
    ...props.form,
    [key]: val,
  });
}
</script>

<template>
  <q-dialog v-model="isOpen" persistent @hide="emit('hide')">
    <q-card style="width: 450px; max-width: 95vw" class="floating-surface shadow-2 q-pa-md">
      <q-card-section class="row items-center justify-between q-pb-sm">
        <div class="text-h6 text-weight-bold">Quick Register Stock</div>
        <q-btn flat round dense icon="ph ph-x" v-close-popup />
      </q-card-section>
      <q-separator />

      <q-card-section class="q-pt-md">
        <div class="q-gutter-md">
          <q-select
            :model-value="form.shipment_id"
            outlined
            dense
            label="Shipment *"
            :options="shipments"
            option-value="id"
            option-label="name"
            emit-value
            map-options
            class="soft-input"
            @update:model-value="(val) => { updateFormField('shipment_id', val); emit('quick-shipment-change'); }"
          />

          <q-select
            :model-value="form.box_id"
            outlined
            dense
            label="Box"
            :options="quickAddFilteredBoxes"
            option-value="id"
            option-label="name"
            emit-value
            map-options
            class="soft-input"
            clearable
            @update:model-value="(val) => updateFormField('box_id', val)"
          />

          <q-input
            :model-value="form.brand_name"
            outlined
            dense
            label="Brand name *"
            class="soft-input"
            :rules="[(val) => !!String(val || '').trim() || 'Required']"
            @update:model-value="(val) => updateFormField('brand_name', String(val ?? ''))"
          />

          <q-select
            :model-value="form.condition"
            outlined
            dense
            label="Condition *"
            :options="[...conditionSelectOptions]"
            class="soft-input"
            :rules="[(val) => !!val || 'Required']"
            @update:model-value="(val) => updateFormField('condition', String(val ?? 'EXCELLENT'))"
          />

          <q-input
            :model-value="form.product_weight"
            outlined
            dense
            type="number"
            min="1"
            step="1"
            label="Product weight (g) *"
            suffix="g"
            class="soft-input"
            :rules="[(val) => (val != null && Number(val) > 0) || 'Required']"
            @update:model-value="(val) => updateFormField('product_weight', Number(val ?? 0))"
          />

          <!-- Upload Area -->
          <div
            class="text-center q-pa-md border-dashed rounded-borders bg-grey-1 cursor-pointer"
            @click="emit('open-uploader')"
          >
            <div v-if="form.imagePreviewUrl" class="text-center">
              <q-img
                :src="form.imagePreviewUrl"
                style="max-height: 180px; border-radius: 8px"
                fit="contain"
              />
              <div class="text-caption text-grey-8 q-mt-sm">
                Image selected (uploads on submit)
              </div>
            </div>
            <div v-else class="q-py-md">
              <q-icon name="ph ph-cloud-arrow-up" size="40px" color="primary" />
              <div class="text-subtitle2 text-weight-bold text-grey-8 q-mt-xs">
                Select Image *
              </div>
              <div class="text-caption text-grey-6">Click to choose your item photo</div>
            </div>
          </div>

          <!-- Barcode -->
          <div>
            <label class="text-caption text-weight-medium text-grey-8">Barcode</label>
            <q-input
              :model-value="form.barcode"
              outlined
              dense
              readonly
              class="soft-input q-mt-xs"
              placeholder="Select shipment to assign barcode..."
            />
            <div v-if="quickAddBarcodeLoading" class="text-caption text-grey-7 q-mt-xs">
              Loading first available barcode...
            </div>
            <div
              v-else-if="form.shipment_id && !form.barcode"
              class="text-caption text-negative q-mt-xs"
            >
              No available barcode found. Generate barcodes first.
            </div>
          </div>

          <!-- Purchase default -->
          <div class="q-pa-sm rounded-borders bg-grey-2 text-caption text-grey-8">
            <div class="row justify-between">
              <span>Default origin unit price:</span>
              <span class="text-weight-bold">{{
                formatThriftAmount(defaultOriginUnitPrice || 0, quickAddPurchaseCurrency)
              }}</span>
            </div>
          </div>
        </div>
      </q-card-section>

      <q-card-section class="row justify-end q-gutter-sm q-pt-sm">
        <q-btn flat no-caps label="Cancel" v-close-popup />
        <q-btn
          color="primary"
          no-caps
          size="sm"
          class="pill-btn slim-btn px-md"
          label="Submit & Edit Details"
          :loading="quickSubmitting"
          :disabled="!canSubmitQuickAdd"
          @click="emit('submit')"
        />
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<style scoped>
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.border-dashed {
  border: 2px dashed rgba(34, 56, 101, 0.2);
}
</style>
