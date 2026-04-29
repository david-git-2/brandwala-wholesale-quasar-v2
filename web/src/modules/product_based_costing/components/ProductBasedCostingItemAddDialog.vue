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
            :disable="isProductListInputType"
          />

          <q-input
            v-model="form.image_url"
            label="Image URL"
            outlined
            dense
            :disable="isProductListInputType"
          />

          <q-select
            v-model="form.vendor_code"
            :options="vendorOptions"
            emit-value
            map-options
            label="Vendor"
            outlined
            dense
            clearable
            :disable="isProductListInputType"
          />

          <q-select
            v-model="form.market_code"
            :options="marketOptions"
            emit-value
            map-options
            label="Market"
            outlined
            dense
            clearable
            :disable="isProductListInputType"
          />

          <div>
            <div class="text-subtitle2 q-mb-xs">Item Note</div>
            <q-editor
              v-model="form.note"
              min-height="140px"
              :toolbar="[
                ['bold', 'italic', 'underline', 'strike'],
                ['unordered', 'ordered'],
                ['quote', 'hr'],
                ['undo', 'redo'],
              ]"
            />
          </div>

          <div v-if="form.image_url" class="q-mt-sm" >
            <div class="text-subtitle2 q-mb-sm">Image Preview</div>
            <div style="margin: 0 auto; width: fit-content;">
          <SmartImage :src="form.image_url" style="max-width: 150px;" />
</div>
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
import { computed, onMounted, reactive, watch } from 'vue'
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore'
import SmartImage from 'src/components/SmartImage.vue'
import { useProductStore } from 'src/modules/products/stores/productStore'
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore'
import { useMarketStore } from 'src/modules/market/stores/marketStore'
import { useAuthStore } from 'src/modules/auth/stores/authStore'

interface ProductBasedCostingItemFormData {
  id?: number
  product_based_costing_file_id?: number | null
  name?: string | null
  image_url?: string | null
  note?: string | null
  vendor_code?: string | null
  market_code?: string | null
  quantity?: number | null
  web_link?: string | null
  price_gbp?: number | null
  product_weight?: number | null
  package_weight?: number | null
  status?: string | null
  input_type?: 'manual' | 'product_list' | null
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
const productStore = useProductStore()
const vendorStore = useVendorStore()
const marketStore = useMarketStore()
const authStore = useAuthStore()

const dialogModel = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
})

const isEditMode = computed(() => Boolean(props.itemData?.id))
const isProductListInputType = computed(() => props.itemData?.input_type === 'product_list')

const getInitialForm = () => ({
  product_based_costing_file_id: props.productBasedCostingFileId,
  name: '',
  image_url: '',
  note: '',
  vendor_code: null as string | null,
  market_code: null as string | null,
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
      note: props.itemData.note ?? '',
      vendor_code: props.itemData.vendor_code ?? null,
      market_code: props.itemData.market_code ?? null,
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

const vendorOptions = computed(() => [
  { label: 'Other', value: null as string | null },
  ...vendorStore.items.map((vendor) => ({
    label: `${vendor.name} (${vendor.code})`,
    value: vendor.code,
  })),
])

const marketOptions = computed(() => [
  { label: 'Other', value: null as string | null },
  ...marketStore.items.map((market) => ({
    label: `${market.name} (${market.code})`,
    value: market.code,
  })),
])

const submitForm = async () => {
  if (isEditMode.value && props.itemData?.id) {
    const result = await store.updateProductBasedCostingItem({
      id: props.itemData.id,
      product_based_costing_file_id: props.productBasedCostingFileId,
      name: form.name,
      image_url: form.image_url,
      note: form.note,
      vendor_code: form.vendor_code,
      market_code: form.market_code,
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

  const createProductResult = await productStore.createProduct({
    tenant_id: authStore.tenantId ?? null,
    name: form.name || null,
    image_url: form.image_url || null,
    barcode: null,
    product_code: null,
    price_gbp: form.price_gbp,
    country_of_origin: null,
    brand: null,
    category: null,
    available_units: null,
    tariff_code: null,
    languages: null,
    batch_code_manufacture_date: null,
    expire_date: null,
    minimum_order_quantity: null,
    product_weight: form.product_weight,
    package_weight: form.package_weight,
    vendor_code: form.vendor_code,
    market_code: form.market_code,
    is_available: true,
  })

  if (!createProductResult.success || !createProductResult.data?.id) {
    return
  }

  const result = await store.createProductBasedCostingItem({
    product_based_costing_file_id: props.productBasedCostingFileId,
    product_id: createProductResult.data.id,
    input_type: 'manual',
    name: form.name,
    image_url: form.image_url,
    note: form.note,
    vendor_code: form.vendor_code,
    market_code: form.market_code,
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

onMounted(() => {
  void Promise.all([vendorStore.fetchVendors(), marketStore.fetchMarkets()])
})
</script>

<style scoped>
.border {
  border: 1px solid #e0e0e0;
}
</style>
