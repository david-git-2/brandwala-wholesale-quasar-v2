<template>
  <q-dialog
    :model-value="modelValue"
    persistent
    @update:model-value="emit('update:modelValue', $event)"
  >
    <q-card class="costing-item-add-dialog">
      <q-card-section>
        <div class="text-h6">Add item</div>
        <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
          Add a new costing item with complete product details.
        </p>
      </q-card-section>

      <q-card-section class="costing-item-add-dialog__grid">
        <q-input
          v-model="form.websiteUrl"
          label="Website URL"
          outlined
          dense
          :rules="[(value) => !!String(value ?? '').trim() || 'Website URL is required.']"
        />
        <q-input
          v-model.number="form.quantity"
          label="Quantity"
          type="number"
          outlined
          dense
          min="1"
          :rules="[
            (value) =>
              (value !== null && value !== '' && Number(value) > 0) ||
              'Quantity is required.',
          ]"
        />
        <q-input
          v-model="form.imageUrl"
          label="Product image URL"
          outlined
          dense
          :rules="[(value) => !!String(value ?? '').trim() || 'Product image URL is required.']"
        />
        <div v-if="previewImageUrl" class="costing-item-add-dialog__preview">
          <q-img
            :src="previewImageUrl"
            fit="contain"
            class="costing-item-add-dialog__preview-image"
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
        <q-btn
          flat
          label="Cancel"
          :disable="loading"
          @click="emit('update:modelValue', false)"
        />
        <q-btn
          color="primary"
          unelevated
          label="Add item"
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

const props = defineProps<{
  modelValue: boolean
  loading?: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  save: [
    payload: {
      websiteUrl: string
      quantity: number
      name: string
      imageUrl: string
      productWeight: number
      packageWeight: number
      priceInWebGbp: number
      deliveryPriceGbp: number
    },
  ]
}>()

const form = reactive({
  websiteUrl: '',
  quantity: 1,
  name: '',
  imageUrl: '',
  productWeight: null as number | null,
  packageWeight: null as number | null,
  priceInWebGbp: null as number | null,
  deliveryPriceGbp: null as number | null,
})

const normalizeExternalUrl = (value: string) =>
  /^https?:\/\//i.test(value) ? value : `https://${value}`

const previewImageUrl = computed(() => {
  const value = form.imageUrl.trim()
  return value ? normalizeExternalUrl(value) : ''
})

const isFormInvalid = computed(() => {
  if (!form.websiteUrl.trim()) return true
  if (!form.imageUrl.trim()) return true
  if (!form.name.trim()) return true
  if (form.quantity == null || Number.isNaN(Number(form.quantity)) || Number(form.quantity) <= 0) return true
  if (form.priceInWebGbp == null || Number.isNaN(Number(form.priceInWebGbp))) return true
  if (form.productWeight == null || Number.isNaN(Number(form.productWeight))) return true
  if (form.packageWeight == null || Number.isNaN(Number(form.packageWeight))) return true
  if (form.deliveryPriceGbp == null || Number.isNaN(Number(form.deliveryPriceGbp))) return true

  return false
})

const resetForm = () => {
  form.websiteUrl = ''
  form.quantity = 1
  form.name = ''
  form.imageUrl = ''
  form.productWeight = null
  form.packageWeight = null
  form.priceInWebGbp = null
  form.deliveryPriceGbp = null
}

const handleSave = () => {
  emit('save', {
    websiteUrl: form.websiteUrl.trim(),
    quantity: Math.max(1, Number(form.quantity || 1)),
    name: form.name.trim(),
    imageUrl: form.imageUrl.trim(),
    productWeight: Number(form.productWeight),
    packageWeight: Number(form.packageWeight),
    priceInWebGbp: Number(form.priceInWebGbp),
    deliveryPriceGbp: Number(form.deliveryPriceGbp),
  })
}

watch(
  () => props.modelValue,
  (isOpen) => {
    if (isOpen) {
      resetForm()
    }
  },
)
</script>

<style scoped>
.costing-item-add-dialog {
  width: min(560px, 92vw);
}

.costing-item-add-dialog__grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 1rem;
}

.costing-item-add-dialog__preview {
  overflow: hidden;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 16px;
  background: rgba(248, 250, 252, 0.9);
}

.costing-item-add-dialog__preview-image {
  height: 180px;
}
</style>
