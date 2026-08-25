<script setup lang="ts">
import { computed } from 'vue';
import type { ThriftSection, ThriftCondition } from '../types';
import type { ThriftCurrency } from 'src/modules/thrift/currency/types';
import type { ThriftStockPricingInput } from '../repositories/thriftStockRepository';
import { resolveTypeIcon } from 'src/modules/thrift/type/utils/typeIcon';

interface CategoryOption {
  id: number;
  name: string;
}

interface TypeOption {
  id: number;
  name: string;
  icon?: string | null;
}

interface BoxOption {
  id: number;
  name: string;
  shipment_id?: number | null;
}

interface ShelfOption {
  id: number;
  shelf_code: string;
}

interface ShipmentOption {
  id: number;
  name: string;
}

interface RegisterForm {
  category_id: number | null;
  type_id: number | null;
  shipment_id: number | null;
  box_id: number | null;
  name: string;
  brand_name: string;
  barcode: string;
  section: ThriftSection | null;
  shelf_id: number | null;
  color: string;
  size: string;
  condition: ThriftCondition | null;
  quantity: number;
  product_weight: number;
  extra_weight: number;
  note: string;
}

interface EditImageState {
  url: string;
  originalUrl: string;
  pendingBlob: Blob | null;
  pendingPreviewUrl: string | null;
  removed: boolean;
}

const props = defineProps<{
  modelValue: boolean;
  editingId: number | null;
  form: RegisterForm;
  editImage: EditImageState;
  shipments: ShipmentOption[];
  filteredBoxes: BoxOption[];
  categories: CategoryOption[];
  types: TypeOption[];
  shelves: ShelfOption[];
  purchaseCurrency?: ThriftCurrency | undefined;
  costCurrency?: ThriftCurrency | undefined;
  purchaseCurrencySymbol: string;
  costCurrencySymbol: string;
  originUnitPrice: number;
  extraOriginUnitPrice: number;
  additionalChargesCost: number;
  pricing: ThriftStockPricingInput;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'update:form', val: RegisterForm): void;
  (e: 'update:originUnitPrice', val: number): void;
  (e: 'update:extraOriginUnitPrice', val: number): void;
  (e: 'update:additionalChargesCost', val: number): void;
  (e: 'update:pricing', val: ThriftStockPricingInput): void;
  (e: 'shipment-change'): void;
  (e: 'open-uploader'): void;
  (e: 'remove-image-click'): void;
  (e: 'submit'): void;
  (e: 'hide'): void;
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val: boolean) => emit('update:modelValue', val),
});

function updateFormField<K extends keyof RegisterForm>(key: K, val: RegisterForm[K]) {
  emit('update:form', {
    ...props.form,
    [key]: val,
  });
}
</script>

<template>
  <q-dialog v-model="isOpen" persistent @hide="emit('hide')">
    <q-card style="width: 600px; max-width: 95vw" class="floating-surface shadow-2 q-pa-md">
      <q-card-section class="row items-center justify-between q-pb-sm">
        <div class="text-h6 text-weight-bold">
          {{ editingId ? 'Edit Thrift Stock' : 'Register Thrift Stock' }}
        </div>
        <q-btn flat round dense icon="ph ph-x" v-close-popup />
      </q-card-section>
      <q-separator />
      <q-card-section>
        <q-form @submit.prevent="emit('submit')" class="q-gutter-sm q-pt-sm">
          <!-- Product Image -->
          <div>
            <div class="text-caption text-grey-8 q-mb-xs">Product Image</div>
            <div
              v-if="editImage.url"
              class="stock-image-preview relative-position text-center q-pa-sm rounded-borders"
            >
              <q-img
                :src="editImage.url"
                style="max-height: 200px; border-radius: 8px"
                fit="contain"
                spinner-color="primary"
              />
              <div class="row justify-center q-gutter-sm q-mt-sm">
                <q-btn
                  flat
                  dense
                  no-caps
                  color="primary"
                  icon="ph ph-cloud-arrow-up"
                  label="Replace"
                  @click="emit('open-uploader')"
                />
                <q-btn
                  flat
                  dense
                  no-caps
                  color="negative"
                  icon="ph ph-trash"
                  label="Remove"
                  @click="emit('remove-image-click')"
                />
              </div>
            </div>
            <div
              v-else
              class="stock-image-upload text-center q-pa-lg rounded-borders cursor-pointer"
              @click="emit('open-uploader')"
            >
              <q-icon name="ph ph-cloud-arrow-up" size="40px" color="primary" />
              <div class="text-subtitle2 text-weight-bold text-grey-8 q-mt-xs">Upload Image</div>
              <div class="text-caption text-grey-6">
                Click to select photo (uploads when you save)
              </div>
            </div>
          </div>

          <q-separator />

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
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
                :rules="[(val) => !!val || 'Required']"
                @update:model-value="(val) => { updateFormField('shipment_id', val); emit('shipment-change'); }"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-select
                :model-value="form.box_id"
                outlined
                dense
                label="Box Number/Name"
                :options="filteredBoxes"
                option-value="id"
                option-label="name"
                emit-value
                map-options
                class="soft-input"
                clearable
                @update:model-value="(val) => updateFormField('box_id', val)"
              />
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-select
                :model-value="form.category_id"
                outlined
                dense
                label="Category *"
                :options="categories"
                option-value="id"
                option-label="name"
                emit-value
                map-options
                class="soft-input"
                :rules="[(val) => !!val || 'Required']"
                @update:model-value="(val) => updateFormField('category_id', val)"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-select
                :model-value="form.type_id"
                outlined
                dense
                label="Product Style/Type *"
                :options="types"
                option-value="id"
                option-label="name"
                emit-value
                map-options
                class="soft-input"
                :rules="[(val) => !!val || 'Required']"
                @update:model-value="(val) => updateFormField('type_id', val)"
              >
                <template #option="scope">
                  <q-item v-bind="scope.itemProps">
                    <q-item-section avatar>
                      <q-icon :name="resolveTypeIcon(scope.opt.icon)" />
                    </q-item-section>
                    <q-item-section>{{ scope.opt.name }}</q-item-section>
                  </q-item>
                </template>
                <template #selected-item="scope">
                  <span v-if="scope.opt" class="row items-center no-wrap">
                    <q-icon :name="resolveTypeIcon(scope.opt.icon)" class="q-mr-sm" />
                    {{ scope.opt.name }}
                  </span>
                </template>
              </q-select>
            </div>
          </div>

          <q-input
            :model-value="form.name"
            outlined
            dense
            label="Item Name"
            class="soft-input"
            @update:model-value="(val) => updateFormField('name', String(val ?? ''))"
          />

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                :model-value="form.brand_name"
                outlined
                dense
                label="Brand Name"
                class="soft-input"
                @update:model-value="(val) => updateFormField('brand_name', String(val ?? ''))"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                :model-value="form.barcode"
                outlined
                dense
                label="Barcode *"
                class="soft-input"
                :rules="[(val) => (!!val && val.length > 0) || 'Required']"
                @update:model-value="(val) => updateFormField('barcode', String(val ?? ''))"
              />
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-4">
              <q-select
                :model-value="form.section"
                outlined
                dense
                label="Section"
                class="soft-input"
                :options="['MALE', 'FEMALE', 'UNISEX', 'KIDS', 'HOME']"
                clearable
                @update:model-value="(val) => updateFormField('section', val as ThriftSection | null)"
              />
            </div>
            <div class="col-12 col-sm-4">
              <q-select
                :model-value="form.condition"
                outlined
                dense
                label="Condition"
                class="soft-input"
                :options="['NEW_WITH_TAGS', 'EXCELLENT', 'GOOD', 'FAIR']"
                clearable
                @update:model-value="(val) => updateFormField('condition', val as ThriftCondition | null)"
              />
            </div>
            <div class="col-12 col-sm-4">
              <q-select
                :model-value="form.shelf_id"
                outlined
                dense
                label="Shelf"
                class="soft-input"
                :options="shelves"
                option-value="id"
                option-label="shelf_code"
                emit-value
                map-options
                clearable
                @update:model-value="(val) => updateFormField('shelf_id', val)"
              />
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-4">
              <q-input
                :model-value="form.color"
                outlined
                dense
                label="Color"
                class="soft-input"
                @update:model-value="(val) => updateFormField('color', String(val ?? ''))"
              />
            </div>
            <div class="col-12 col-sm-4">
              <q-input
                :model-value="form.size"
                outlined
                dense
                label="Size"
                class="soft-input"
                @update:model-value="(val) => updateFormField('size', String(val ?? ''))"
              />
            </div>
            <div class="col-12 col-sm-4">
              <q-input
                :model-value="form.quantity"
                type="number"
                outlined
                dense
                label="Quantity *"
                class="soft-input"
                :rules="[(val) => val >= 0 || 'Cannot be negative']"
                @update:model-value="(val) => updateFormField('quantity', Number(val ?? 0))"
              />
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                :model-value="form.product_weight"
                type="number"
                step="1"
                outlined
                dense
                label="Product Weight (g)"
                class="soft-input"
                @update:model-value="(val) => updateFormField('product_weight', Number(val ?? 0))"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                :model-value="form.extra_weight"
                type="number"
                step="1"
                outlined
                dense
                label="Extra Weight (g)"
                class="soft-input"
                @update:model-value="(val) => updateFormField('extra_weight', Number(val ?? 0))"
              />
            </div>
          </div>

          <q-separator class="q-my-xs" />
          <div class="text-caption text-grey-8 q-mb-xs">
            Purchase ({{ purchaseCurrency?.code ?? '—' }})
          </div>
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                :model-value="originUnitPrice"
                type="number"
                step="0.01"
                min="0"
                outlined
                dense
                label="Origin unit price"
                :prefix="purchaseCurrencySymbol"
                class="soft-input"
                @update:model-value="(val) => emit('update:originUnitPrice', Number(val ?? 0))"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input
                :model-value="extraOriginUnitPrice"
                type="number"
                step="0.01"
                min="0"
                outlined
                dense
                label="Extra origin unit price"
                :prefix="purchaseCurrencySymbol"
                class="soft-input"
                @update:model-value="(val) => emit('update:extraOriginUnitPrice', Number(val ?? 0))"
              />
            </div>
          </div>
          <div class="row q-col-gutter-sm q-mt-xs">
            <div class="col-12 col-sm-6">
              <q-input
                :model-value="additionalChargesCost"
                type="number"
                step="0.01"
                min="0"
                outlined
                dense
                label="Additional charges cost"
                :prefix="costCurrencySymbol"
                class="soft-input"
                @update:model-value="(val) => emit('update:additionalChargesCost', Number(val ?? 0))"
              />
            </div>
          </div>

          <q-separator class="q-my-xs" />
          <div class="text-caption text-grey-8 q-mb-xs">
            Pricing ({{ costCurrency?.code ?? '—' }})
          </div>
          <div class="row q-col-gutter-sm">
            <div class="col-12">
              <q-input
                :model-value="pricing.listed_unit_price"
                type="number"
                step="1"
                outlined
                dense
                label="Listed Price"
                :prefix="costCurrencySymbol"
                class="soft-input"
                @update:model-value="(val) => emit('update:pricing', { ...pricing, listed_unit_price: Number(val ?? 0) })"
              />
            </div>
          </div>

          <div class="row justify-end q-gutter-sm q-pt-sm">
            <q-btn flat no-caps label="Cancel" v-close-popup />
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              label="Save Stock"
              type="submit"
            />
          </div>
        </q-form>
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
  border-radius: 8px;
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

.stock-image-preview {
  border: 1px solid rgba(34, 56, 101, 0.1);
  background: rgba(247, 249, 252, 0.8);
}

.stock-image-upload {
  border: 2px dashed rgba(34, 56, 101, 0.2);
  background: rgba(247, 249, 252, 0.6);
  transition:
    border-color 0.2s ease,
    background 0.2s ease;
}

.stock-image-upload:hover {
  border-color: var(--q-primary);
  background: rgba(var(--q-primary-rgb, 25, 118, 210), 0.04);
}
</style>
