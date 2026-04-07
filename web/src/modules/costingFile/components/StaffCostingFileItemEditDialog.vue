<template>
  <q-dialog
    :model-value="modelValue"
    persistent
    @update:model-value="emit('update:modelValue', $event)"
  >
    <q-card class="costing-item-edit-dialog">
      <q-card-section>
        <div class="text-h6">Edit item</div>
        <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
          Update item #{{ item?.id }} details.
        </p>
      </q-card-section>

      <q-card-section class="costing-item-edit-dialog__grid">
        <q-input
          v-model="form.imageUrl"
          label="Product image URL"
          outlined
          dense
          :rules="[(value) => !!String(value ?? '').trim() || 'Product image URL is required.']"
        />
        <div v-if="previewImageUrl" class="costing-item-edit-dialog__preview">
          <q-img
            :src="previewImageUrl"
            fit="contain"
            class="costing-item-edit-dialog__preview-image"
          />
        </div>
        <q-input
          v-model="form.name"
          label="Name"
          outlined
          type="textarea"
          dense
          :rules="[(value) => !!String(value ?? '').trim() || 'Name is required.']"
        />
        <q-select
          v-model="form.itemType"
          :options="itemTypeOptions"
          label="Type"
          outlined
          dense
          clearable
          hint="Pick the closest product type."
        />
        <q-input
          v-model.number="form.priceInWebGbp"
          label="Web price (GBP)"
          type="number"
          outlined
          dense
          min="0"
          :rules="[
            (value) =>
              (value !== null && value !== '' && !Number.isNaN(Number(value))) ||
              'Web price is required.',
          ]"
        />
        <q-input
          v-model.number="form.productWeight"
          label="Product weight (g/ml)"
          type="number"
          outlined
          dense
          min="0"
          :rules="[
            (value) =>
              (value !== null && value !== '' && !Number.isNaN(Number(value))) ||
              'Product weight is required.',
          ]"
        />
        <q-input
          v-model.number="form.packageWeight"
          label="Package weight (g/ml)"
          type="number"
          outlined
          dense
          min="0"
          :rules="[
            (value) =>
              (value !== null && value !== '' && !Number.isNaN(Number(value))) ||
              'Package weight is required.',
          ]"
        />
        <q-input
          v-model.number="form.deliveryPriceGbp"
          label="Delivery charge (GBP)"
          type="number"
          outlined
          dense
          min="0"
          :rules="[
            (value) =>
              (value !== null && value !== '' && !Number.isNaN(Number(value))) ||
              'Delivery charge is required.',
          ]"
        />
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
import { computed, reactive, watch } from 'vue'

import type { CostingFileItem } from 'src/modules/costingFile/types'

const props = defineProps<{
  modelValue: boolean
  item: CostingFileItem | null
  loading?: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
      save: [
        payload: {
          id: number
          name: string
          itemType: string | null
          imageUrl: string
          productWeight: number
          packageWeight: number
      priceInWebGbp: number
      deliveryPriceGbp: number
    },
  ]
}>()

const form = reactive({
  name: '',
  itemType: '' as string | null,
  imageUrl: '',
  productWeight: null as number | null,
  packageWeight: null as number | null,
  priceInWebGbp: null as number | null,
  deliveryPriceGbp: null as number | null,
})

const itemTypeOptions = ['Watch', 'Perfume', 'Others']

const normalizeExternalUrl = (value: string) =>
  /^https?:\/\//i.test(value) ? value : `https://${value}`

const previewImageUrl = computed(() => {
  const value = form.imageUrl.trim()
  return value ? normalizeExternalUrl(value) : ''
})

const isFormInvalid = computed(() => {
  if (!form.imageUrl.trim()) return true
  if (!form.name.trim()) return true
  if (form.priceInWebGbp == null || Number.isNaN(Number(form.priceInWebGbp))) return true
  if (form.productWeight == null || Number.isNaN(Number(form.productWeight))) return true
  if (form.packageWeight == null || Number.isNaN(Number(form.packageWeight))) return true
  if (form.deliveryPriceGbp == null || Number.isNaN(Number(form.deliveryPriceGbp))) return true

  return false
})

const syncForm = (item: CostingFileItem | null) => {
  form.name = item?.name ?? ''
  form.itemType = item?.item_type ?? null
  form.imageUrl = item?.image_url ?? ''
  form.productWeight = item?.product_weight ?? null
  form.packageWeight = item?.package_weight ?? null
  form.priceInWebGbp = item?.price_in_web_gbp ?? null
  form.deliveryPriceGbp = item?.delivery_price_gbp ?? null
}

const handleSave = () => {
  if (!props.item) {
    return
  }

  emit('save', {
    id: props.item.id,
    name: form.name.trim(),
    itemType: form.itemType?.trim() || null,
    imageUrl: form.imageUrl.trim(),
    productWeight: Number(form.productWeight),
    packageWeight: Number(form.packageWeight),
    priceInWebGbp: Number(form.priceInWebGbp),
    deliveryPriceGbp: Number(form.deliveryPriceGbp),
  })
}

watch(
  () => props.item,
  (item) => {
    syncForm(item)
  },
  { immediate: true },
)

watch(
  () => props.modelValue,
  (isOpen) => {
    if (isOpen) {
      syncForm(props.item)
    }
  },
)
</script>

<style scoped>
.costing-item-edit-dialog {
  width: min(560px, 92vw);
}

.costing-item-edit-dialog__grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 1rem;
}

.costing-item-edit-dialog__preview {
  overflow: hidden;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 16px;
  background: rgba(248, 250, 252, 0.9);
}

.costing-item-edit-dialog__preview-image {
  height: 180px;
}
</style>
