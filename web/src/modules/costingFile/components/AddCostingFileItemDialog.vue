<template>
  <q-dialog
    :model-value="modelValue"
    persistent
    @update:model-value="emit('update:modelValue', $event)"
  >
    <q-card class="costing-item-add-dialog">
      <q-card-section class="costing-item-add-dialog__header">
        <div>
          <div class="text-h6">Add item</div>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Add a new costing item with complete product details.
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

      <q-card-section class="costing-item-add-dialog__grid">
        <div class="costing-item-add-dialog__preview-pane">
          <div v-if="previewImageUrl" class="costing-item-add-dialog__preview">
            <q-img
              :src="previewImageUrl"
              fit="contain"
              class="costing-item-add-dialog__preview-image"
            />
          </div>
          <div v-else class="costing-item-add-dialog__preview costing-item-add-dialog__preview--empty">
            <q-icon name="image" size="32px" />
            <div class="text-caption q-mt-sm">Image preview</div>
          </div>

          <div class="costing-item-add-dialog__preview-fields">
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
              :rules="[(value) => !!String(value ?? '').trim() || 'Website URL is required.']"
            >
              <template #prepend><q-icon name="link" /></template>
            </q-input>
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
            >
              <template #prepend><q-icon name="inventory_2" /></template>
            </q-input>
          </div>
        </div>

        <div class="costing-item-add-dialog__form-pane">
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
          v-model="form.size"
          label="Size"
          outlined
          dense
          hint="Example: XL, 250ml, 42"
        >
          <template #prepend><q-icon name="straighten" /></template>
        </q-input>
        <q-input
          v-model="form.color"
          label="Color"
          outlined
          dense
        >
          <template #prepend><q-icon name="palette" /></template>
        </q-input>
        <q-input
          v-model="form.extraInformation1"
          label="Extra information 1"
          outlined
          dense
          type="textarea"
          autogrow
        >
          <template #prepend><q-icon name="notes" /></template>
        </q-input>
        <q-input
          v-model="form.extraInformation2"
          label="Extra information 2"
          outlined
          dense
          type="textarea"
          autogrow
        >
          <template #prepend><q-icon name="notes" /></template>
        </q-input>
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
        >
          <template #prepend><q-icon name="currency_pound" /></template>
        </q-input>
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
        >
          <template #prepend><q-icon name="fitness_center" /></template>
        </q-input>
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
        >
          <template #prepend><q-icon name="scale" /></template>
        </q-input>
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
        >
          <template #prepend><q-icon name="local_shipping" /></template>
        </q-input>
        </div>
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
          itemType: string | null
          size: string | null
          color: string | null
          extraInformation1: string | null
          extraInformation2: string | null
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
  itemType: '' as string | null,
  size: '',
  color: '',
  extraInformation1: '',
  extraInformation2: '',
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
  form.itemType = ''
  form.size = ''
  form.color = ''
  form.extraInformation1 = ''
  form.extraInformation2 = ''
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
    itemType: form.itemType?.trim() || null,
    size: form.size.trim() || null,
    color: form.color.trim() || null,
    extraInformation1: form.extraInformation1.trim() || null,
    extraInformation2: form.extraInformation2.trim() || null,
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
  width: min(1080px, 97vw);
}

.costing-item-add-dialog__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
}

.costing-item-add-dialog__grid {
  display: grid;
  grid-template-columns: 260px minmax(0, 1fr);
  gap: 1rem;
  align-items: start;
}

.costing-item-add-dialog__preview-pane {
  position: sticky;
  top: 0;
}

.costing-item-add-dialog__preview-fields {
  display: grid;
  gap: 0.75rem;
  margin-top: 0.75rem;
}

.costing-item-add-dialog__form-pane {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 0.9rem;
}

.costing-item-add-dialog__preview {
  overflow: hidden;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 16px;
  background: rgba(248, 250, 252, 0.9);
}

.costing-item-add-dialog__preview-image {
  height: 240px;
}

.costing-item-add-dialog__preview--empty {
  height: 240px;
  display: grid;
  place-items: center;
  color: #64748b;
}

@media (max-width: 900px) {
  .costing-item-add-dialog__grid {
    grid-template-columns: minmax(0, 1fr);
  }

  .costing-item-add-dialog__preview-pane {
    position: static;
  }

  .costing-item-add-dialog__form-pane {
    grid-template-columns: minmax(0, 1fr);
  }
}
</style>
