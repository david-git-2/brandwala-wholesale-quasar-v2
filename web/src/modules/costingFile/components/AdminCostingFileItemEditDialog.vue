<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card class="costing-item-edit-dialog">
      <q-card-section>
        <div class="text-h6">Edit item</div>
        <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
          Update product details for item #{{ item?.id }}.
        </p>
      </q-card-section>

      <q-card-section class="costing-item-edit-dialog__grid">
        <q-input v-model="form.name" label="Name" outlined dense clearable />
        <q-input v-model.number="form.productWeight" label="Product weight" type="number" outlined dense clearable />
        <q-input v-model.number="form.packageWeight" label="Package weight" type="number" outlined dense clearable />
        <q-input v-model="form.imageUrl" label="Image URL" outlined dense clearable />
        <q-input v-model.number="form.priceInWebGbp" label="Price in web" type="number" outlined dense clearable />
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" :disable="loading" @click="emit('update:modelValue', false)" />
        <q-btn color="primary" unelevated label="Save" :loading="loading" @click="handleSave" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { reactive, watch } from 'vue'

import type { CostingFileItem } from 'src/modules/costingFile/types'

const props = defineProps<{
  modelValue: boolean
  item: CostingFileItem | null
  loading?: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  save: [payload: { id: number; name: string | null; productWeight: number | null; packageWeight: number | null; imageUrl: string | null; priceInWebGbp: number | null }]
}>()

const form = reactive({
  name: '',
  productWeight: null as number | null,
  packageWeight: null as number | null,
  imageUrl: '',
  priceInWebGbp: null as number | null,
})

const syncForm = (item: CostingFileItem | null) => {
  form.name = item?.name ?? ''
  form.productWeight = item?.product_weight ?? null
  form.packageWeight = item?.package_weight ?? null
  form.imageUrl = item?.image_url ?? ''
  form.priceInWebGbp = item?.price_in_web_gbp ?? null
}

const handleSave = () => {
  if (!props.item) return

  emit('save', {
    id: props.item.id,
    name: form.name.trim() || null,
    productWeight: form.productWeight,
    packageWeight: form.packageWeight,
    imageUrl: form.imageUrl.trim() || null,
    priceInWebGbp: form.priceInWebGbp,
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
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1rem;
}

@media (max-width: 599px) {
  .costing-item-edit-dialog__grid {
    grid-template-columns: 1fr;
  }
}
</style>
