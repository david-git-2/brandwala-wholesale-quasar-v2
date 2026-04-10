<template>
  <q-dialog v-model="dialogModel" persistent>
    <q-card style="min-width: 520px; max-width: 90vw;">
      <q-card-section class="row items-center justify-between">
        <div class="text-h6 text-weight-bold">
          {{ isEditMode ? 'Edit Product Based Costing Item' : 'Add Product Based Costing Item' }}
        </div>

        <q-btn
          icon="close"
          flat
          round
          dense
          v-close-popup
        />
      </q-card-section>

      <q-separator />

      <q-card-section>
        <q-form class="q-gutter-md" @submit.prevent="submitForm">
          <q-input
            v-model="form.name"
            label="Name"
            outlined
            dense
          />

          <q-input
            v-model="form.image_url"
            label="Image URL"
            outlined
            dense
          />

          <div v-if="form.image_url" class="q-mt-sm">
            <div class="text-subtitle2 q-mb-sm">Image Preview</div>

            <q-img
              :src="form.image_url"
              fit="contain"
              style="max-width: 220px; height: 220px;"
              class="rounded-borders border"
            >
              <template #error>
                <div class="full-width full-height flex flex-center bg-grey-3 text-grey-7">
                  Failed to load image
                </div>
              </template>
            </q-img>
          </div>

          <q-input
            v-model.number="form.quantity"
            label="Quantity"
            type="number"
            outlined
            dense
          />

          <q-input
            v-model="form.web_link"
            label="Web Link"
            outlined
            dense
          />

          <q-input
            v-model.number="form.price_gbp"
            label="Price GBP"
            type="number"
            outlined
            dense
          />

          <q-input
            v-model.number="form.product_weight"
            label="Product Weight"
            type="number"
            outlined
            dense
          />

          <q-input
            v-model.number="form.package_weight"
            label="Package Weight"
            type="number"
            outlined
            dense
          />
        </q-form>
      </q-card-section>

      <q-separator />

      <q-card-actions align="right">
        <q-btn
          flat
          label="Cancel"
          v-close-popup
        />
        <q-btn
          color="primary"
          :label="isEditMode ? 'Update' : 'Save'"
          :loading="store.saving"
          @click="submitForm"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, watch } from 'vue'
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore'

interface ProductBasedCostingItemFormData {
  id?: number
  product_based_costing_file_id?: number | null
  name?: string | null
  image_url?: string | null
  quantity?: number | null
  web_link?: string | null
  price_gbp?: number | null
  product_weight?: number | null
  package_weight?: number | null
  status?: string | null
}

const props = defineProps<{
  modelValue: boolean
  productBasedCostingFileId: number
  itemData?: ProductBasedCostingItemFormData | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'created'): void
  (e: 'updated'): void
}>()

const store = useProductBasedCostingStore()

const dialogModel = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
})

const isEditMode = computed(() => Boolean(props.itemData?.id))

const getInitialForm = () => ({
  product_based_costing_file_id: props.productBasedCostingFileId,
  name: '',
  image_url: '',
  quantity: null as number | null,
  web_link: '',
  price_gbp: null as number | null,
  product_weight: null as number | null,
  package_weight: null as number | null,
  status: 'pending',
})

const form = reactive(getInitialForm())

const fillForm = () => {
  if (props.itemData?.id) {
    Object.assign(form, {
      product_based_costing_file_id:
        props.itemData.product_based_costing_file_id ?? props.productBasedCostingFileId,
      name: props.itemData.name ?? '',
      image_url: props.itemData.image_url ?? '',
      quantity: props.itemData.quantity ?? null,
      web_link: props.itemData.web_link ?? '',
      price_gbp: props.itemData.price_gbp ?? null,
      product_weight: props.itemData.product_weight ?? null,
      package_weight: props.itemData.package_weight ?? null,
      status: props.itemData.status ?? 'pending',
    })
  } else {
    Object.assign(form, getInitialForm())
  }
}

const resetForm = () => {
  Object.assign(form, getInitialForm())
}

const submitForm = async () => {
  if (isEditMode.value && props.itemData?.id) {
    const result = await store.updateProductBasedCostingItem({
      id: props.itemData.id,
      product_based_costing_file_id: props.productBasedCostingFileId,
      name: form.name,
      image_url: form.image_url,
      quantity: form.quantity,
      web_link: form.web_link,
      price_gbp: form.price_gbp,
      product_weight: form.product_weight,
      package_weight: form.package_weight,
      status: form.status || 'pending',
    })

    if (!result.success) {
      return
    }

    emit('updated')
    emit('update:modelValue', false)
    resetForm()
    return
  }

  const result = await store.createProductBasedCostingItem({
    product_based_costing_file_id: props.productBasedCostingFileId,
    name: form.name,
    image_url: form.image_url,
    quantity: form.quantity,
    web_link: form.web_link,
    price_gbp: form.price_gbp,
    product_weight: form.product_weight,
    package_weight: form.package_weight,
    status: 'pending',
  })

  if (!result.success) {
    return
  }

  emit('created')
  emit('update:modelValue', false)
  resetForm()
}

watch(
  () => [props.modelValue, props.itemData],
  ([value]) => {
    if (value) {
      fillForm()
    }
  },
  { immediate: true, deep: true },
)
</script>

<style scoped>
.border {
  border: 1px solid #e0e0e0;
}
</style>
