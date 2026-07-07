<template>
  <q-dialog
    :model-value="modelValue"
    persistent
    @update:model-value="emit('update:modelValue', $event)"
  >
    <q-card class="costing-item-edit-dialog">
      <q-card-section class="costing-item-edit-dialog__header">
        <div>
          <div class="text-h6">Edit item</div>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Update product details for item #{{ item?.id }}.
          </p>
        </div>
        <q-btn
          flat
          dense
          round
          icon="close"
          aria-label="Close"
          :disable="loading"
          @click="emit('update:modelValue', false)"
        />
      </q-card-section>

      <q-card-section class="costing-item-edit-dialog__grid">
        <div class="costing-item-edit-dialog__preview-pane">
          <div v-if="previewImageUrl" class="costing-item-edit-dialog__preview">
            <q-img
              :src="previewImageUrl"
              fit="contain"
              class="costing-item-edit-dialog__preview-image"
            />
          </div>
          <div v-else class="costing-item-edit-dialog__preview costing-item-edit-dialog__preview--empty">
            <q-icon name="image" size="32px" />
            <div class="text-caption q-mt-sm">Image preview</div>
          </div>

          <div class="costing-item-edit-dialog__preview-fields">
            <q-input
              v-model="form.imageUrl"
              label="Product URL"
              outlined
              dense
              :rules="[(value) => !!String(value ?? '').trim() || 'Product image URL is required.']"
            >
              <template #prepend><q-icon name="image" /></template>
            </q-input>
            <q-input
              v-model="form.websiteUrl"
              label="Website URL"
              outlined
              dense
              readonly
            >
              <template #prepend><q-icon name="link" /></template>
              <template #append>
                <q-btn
                  v-if="externalWebsiteUrl"
                  flat
                  dense
                  round
                  icon="open_in_new"
                  aria-label="Open website URL"
                  :href="externalWebsiteUrl"
                  target="_blank"
                  rel="noopener noreferrer"
                />
              </template>
            </q-input>
          </div>
        </div>
        <div class="costing-item-edit-dialog__form-pane">
          <q-input
            v-model="form.name"
            label="Name"
            outlined
            type="textarea"
            dense
            :rules="[(value) => !!String(value ?? '').trim() || 'Name is required.']"
          >
            <template #prepend><q-icon name="badge" /></template>
          </q-input>
          <q-select
            v-model="form.itemType"
            :options="itemTypeOptions"
            label="Type"
            outlined
            dense
            clearable
            hint="Pick the closest product type."
          >
            <template #prepend><q-icon name="category" /></template>
          </q-select>
          <q-input
            v-model.number="form.priceInWebGbp"
            label="Web price (GBP)"
            type="number"
            outlined
            dense
            :rules="[
              (value) =>
                (value !== null && value !== '' && !Number.isNaN(Number(value))) ||
                'Web price is required.',
            ]"
          >
            <template #prepend><q-icon name="currency_pound" /></template>
          </q-input>
          <q-input
            v-model.number="form.productWeight"
            label="Product weight (g/ml)"
            type="number"
            outlined
            dense
            :rules="[
              (value) =>
                (value !== null && value !== '' && !Number.isNaN(Number(value))) ||
                'Product weight is required.',
            ]"
          >
            <template #prepend><q-icon name="fitness_center" /></template>
          </q-input>
          <q-input
            v-model.number="form.packageWeight"
            label="Package weight (g/ml)"
            type="number"
            outlined
            dense
            :rules="[
              (value) =>
                (value !== null && value !== '' && !Number.isNaN(Number(value))) ||
                'Package weight is required.',
            ]"
          >
            <template #prepend><q-icon name="scale" /></template>
          </q-input>
          <q-input
            v-model.number="form.deliveryPriceGbp"
            label="Delivery charge (GBP)"
            type="number"
            outlined
            dense
            :rules="[
              (value) =>
                (value !== null && value !== '' && !Number.isNaN(Number(value))) ||
                'Delivery charge is required.',
            ]"
          >
            <template #prepend><q-icon name="local_shipping" /></template>
          </q-input>
        </div>
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" :disable="loading" @click="emit('update:modelValue', false)" />
        <q-btn
          color="primary"
          unelevated
          label="Save"
          :loading="loading"
          :disable="isFormInvalid"
          @click="handleSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue';

import type { CostingFileItem } from 'src/modules/costingFile/types';

const props = defineProps<{
  modelValue: boolean;
  item: CostingFileItem | null;
  loading?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
      save: [
        payload: {
          id: number;
          name: string | null;
          itemType: string | null;
          productWeight: number | null;
          packageWeight: number | null;
          imageUrl: string | null;
      priceInWebGbp: number | null;
      deliveryPriceGbp: number | null;
    },
  ];
}>();

const form = reactive({
  name: '',
  websiteUrl: '',
  itemType: '',
  productWeight: null as number | null,
  packageWeight: null as number | null,
  imageUrl: '',
  priceInWebGbp: null as number | null,
  deliveryPriceGbp: null as number | null,
});

const itemTypeOptions = ['Watch', 'Perfume', 'Others'];

const normalizeExternalUrl = (value: string) =>
  /^https?:\/\//i.test(value) ? value : `https://${value}`;

const previewImageUrl = computed(() => {
  const value = form.imageUrl.trim();
  return value ? normalizeExternalUrl(value) : '';
});

const externalWebsiteUrl = computed(() => {
  const value = form.websiteUrl.trim();
  return value ? normalizeExternalUrl(value) : '';
});

const isFormInvalid = computed(() => {
  if (!form.imageUrl.trim()) return true;
  if (!form.name.trim()) return true;
  if (form.priceInWebGbp == null || Number.isNaN(Number(form.priceInWebGbp))) return true;
  if (form.productWeight == null || Number.isNaN(Number(form.productWeight))) return true;
  if (form.packageWeight == null || Number.isNaN(Number(form.packageWeight))) return true;
  if (form.deliveryPriceGbp == null || Number.isNaN(Number(form.deliveryPriceGbp))) return true;

  return false;
});

const syncForm = (item: CostingFileItem | null) => {
  form.name = item?.name ?? '';
  form.websiteUrl = item?.website_url ?? '';
  form.itemType = item?.item_type ?? '';
  form.productWeight = item?.product_weight ?? null;
  form.packageWeight = item?.package_weight ?? null;
  form.imageUrl = item?.image_url ?? '';
  form.priceInWebGbp = item?.price_in_web_gbp ?? null;
  form.deliveryPriceGbp = item?.delivery_price_gbp ?? null;
};

const handleSave = () => {
  if (!props.item) return;

  emit('save', {
    id: props.item.id,
    name: form.name.trim() || null,
    itemType: form.itemType?.trim() || null,
    productWeight: form.productWeight,
    packageWeight: form.packageWeight,
    imageUrl: form.imageUrl.trim() || null,
    priceInWebGbp: form.priceInWebGbp,
    deliveryPriceGbp: form.deliveryPriceGbp,
  });
};

watch(
  () => props.item,
  (item) => {
    syncForm(item);
  },
  { immediate: true },
);

watch(
  () => props.modelValue,
  (isOpen) => {
    if (isOpen) {
      syncForm(props.item);
    }
  },
);
</script>

<style scoped>
.costing-item-edit-dialog {
  width: min(1080px, 97vw);
}

.costing-item-edit-dialog__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
}

.costing-item-edit-dialog__grid {
  display: grid;
  grid-template-columns: 260px minmax(0, 1fr);
  gap: 1rem;
  align-items: start;
}

.costing-item-edit-dialog__preview-pane {
  position: sticky;
  top: 0;
}

.costing-item-edit-dialog__preview-fields {
  display: grid;
  gap: 0.75rem;
  margin-top: 0.75rem;
}

.costing-item-edit-dialog__form-pane {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 0.9rem;
}

.costing-item-edit-dialog__preview {
  overflow: hidden;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 16px;
  background: rgba(248, 250, 252, 0.9);
}

.costing-item-edit-dialog__preview-image {
  height: 240px;
}

.costing-item-edit-dialog__preview--empty {
  height: 240px;
  display: grid;
  place-items: center;
  color: #64748b;
}

@media (max-width: 900px) {
  .costing-item-edit-dialog__grid {
    grid-template-columns: minmax(0, 1fr);
  }

  .costing-item-edit-dialog__preview-pane {
    position: static;
  }
}
</style>
