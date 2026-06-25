<template>
  <FilterSidebar
    :model-value="modelValue"
    title="New Product"
    :z-index="zIndex"
    width="min(420px, 92vw)"
    @update:model-value="emit('update:modelValue', $event)"
  >
    <q-form ref="formRef" @submit="onAdd" class="column full-height no-wrap">
      <div class="col scroll q-gutter-y-md q-pb-md">
        <!-- Image URL & Preview -->
        <div>
          <q-input
            v-model="form.image_url"
            label="Image URL"
            filled
            dense
            clearable
          />
          <div v-if="form.image_url" class="row justify-center q-mt-sm">
            <SmartImage
              :src="form.image_url"
              style="height: 100px; width: 100px; object-fit: contain; border: 1px solid #e2e8f0; border-radius: 8px;"
            />
          </div>
        </div>

        <!-- Name -->
        <q-input
          v-model="form.name"
          label="Name *"
          filled
          dense
          :rules="[v => !!v?.trim() || 'Name is required']"
        />

        <!-- Product Code & Barcode -->
        <div class="row q-col-gutter-xs">
          <div class="col-6">
            <q-input
              v-model="form.product_code"
              label="Product Code"
              filled
              dense
            />
          </div>
          <div class="col-6">
            <q-input
              v-model="form.barcode"
              label="Barcode"
              filled
              dense
            />
          </div>
        </div>

        <!-- Vendor Selection -->
        <q-select
          v-model="form.vendor_id"
          :options="vendorOptions"
          label="Vendor *"
          filled
          dense
          emit-value
          map-options
          clearable
          :rules="[v => !!v || 'Vendor is required']"
          @update:model-value="onVendorChange"
        />

        <!-- Brand & Category -->
        <div class="row q-col-gutter-xs">
          <div class="col-6">
            <q-select
              v-model="form.brand"
              :options="brandOptions"
              label="Brand"
              filled
              dense
              use-input
              fill-input
              hide-selected
              new-value-mode="add-unique"
              @filter="filterBrands"
            />
          </div>
          <div class="col-6">
            <q-select
              v-model="form.category"
              :options="categoryOptions"
              label="Category"
              filled
              dense
              use-input
              fill-input
              hide-selected
              new-value-mode="add-unique"
              @filter="filterCategories"
            />
          </div>
        </div>

        <!-- Price & Qty -->
        <div class="row q-col-gutter-xs">
          <div class="col-6">
            <q-input
              v-model.number="form.purchase_price"
              type="number"
              step="0.01"
              label="Price £ *"
              filled
              dense
              :rules="[v => v !== null && v !== undefined && v >= 0 || 'Must be >= 0']"
            />
          </div>
          <div class="col-6">
            <q-input
              v-model.number="form.ordered_quantity"
              type="number"
              label="Qty *"
              filled
              dense
              min="1"
              :rules="[v => v !== null && v !== undefined && v >= 1 || 'Must be >= 1']"
            />
          </div>
        </div>

        <!-- Weights -->
        <div class="row q-col-gutter-xs">
          <div class="col-6">
            <q-input
              v-model.number="form.product_weight"
              type="number"
              label="Product Weight (g)"
              filled
              dense
              min="0"
            />
          </div>
          <div class="col-6">
            <q-input
              v-model.number="form.package_weight"
              type="number"
              label="Package Weight (g)"
              filled
              dense
              min="0"
            />
          </div>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="row justify-end q-gutter-x-sm q-pt-md border-top">
        <q-btn
          flat
          no-caps
          label="Cancel"
          color="grey-7"
          @click="onClose"
        />
        <q-btn
          unelevated
          no-caps
          label="Add to Cart"
          color="primary"
          type="submit"
        />
      </div>
    </q-form>
  </FilterSidebar>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore'
import { productService } from 'src/modules/products/services/productService'
import FilterSidebar from 'src/components/FilterSidebar.vue'
import SmartImage from 'src/components/SmartImage.vue'
import type { ShipmentCartItem } from './AddShipmentItemsPanel.vue'
import type { QForm } from 'quasar'

const props = defineProps<{
  modelValue: boolean
  zIndex?: number
}>()

const emit = defineEmits<{
  (event: 'update:modelValue', value: boolean): void
  (event: 'add', item: Omit<ShipmentCartItem, 'key'>): void
}>()

const authStore = useAuthStore()
const vendorStore = useVendorStore()
const formRef = ref<QForm | null>(null)

const form = ref({
  image_url: '',
  name: '',
  product_code: '',
  barcode: '',
  vendor_id: null as number | null,
  brand: '',
  category: '',
  purchase_price: 0,
  ordered_quantity: 1,
  product_weight: 0,
  package_weight: 0,
})

const allBrands = ref<string[]>([])
const allCategories = ref<string[]>([])
const brandOptions = ref<string[]>([])
const categoryOptions = ref<string[]>([])

const vendorOptions = computed(() =>
  vendorStore.items.map((v) => ({ label: v.name, value: v.id })),
)

const getVendorCode = (vendorId: number | null): string | null => {
  if (!vendorId) return null
  return vendorStore.items.find((v) => v.id === vendorId)?.code ?? null
}

const onVendorChange = async (vendorId: number | null) => {
  form.value.brand = ''
  form.value.category = ''
  allBrands.value = []
  allCategories.value = []

  if (!vendorId) return

  const vendorCode = getVendorCode(vendorId)
  const tenantId = authStore.tenantId

  // Load brands and categories for selected vendor
  const [brandsRes, catsRes] = await Promise.all([
    productService.listBrands({ vendorCode, tenantId }),
    productService.listCategories({ vendorCode, tenantId }),
  ])

  if (brandsRes.success && brandsRes.data) {
    allBrands.value = brandsRes.data
  }
  if (catsRes.success && catsRes.data) {
    allCategories.value = catsRes.data
  }
}

const filterBrands = (val: string, update: (callback: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase().trim()
    brandOptions.value = needle
      ? allBrands.value.filter((v) => v.toLowerCase().includes(needle))
      : allBrands.value
  })
}

const filterCategories = (val: string, update: (callback: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase().trim()
    categoryOptions.value = needle
      ? allCategories.value.filter((v) => v.toLowerCase().includes(needle))
      : allCategories.value
  })
}

const resetForm = () => {
  form.value = {
    image_url: '',
    name: '',
    product_code: '',
    barcode: '',
    vendor_id: null,
    brand: '',
    category: '',
    purchase_price: 0,
    ordered_quantity: 1,
    product_weight: 0,
    package_weight: 0,
  }
  allBrands.value = []
  allCategories.value = []
  if (formRef.value) {
    formRef.value.resetValidation()
  }
}

const onClose = () => {
  resetForm()
  emit('update:modelValue', false)
}

const onAdd = () => {
  emit('add', {
    product_id: null,
    isNewProduct: true,
    vendor_id: form.value.vendor_id,
    name: form.value.name.trim(),
    ordered_quantity: form.value.ordered_quantity,
    purchase_price: form.value.purchase_price,
    product_weight: form.value.product_weight || 0,
    package_weight: form.value.package_weight || 0,
    barcode: form.value.barcode.trim() || null,
    product_code: form.value.product_code.trim() || null,
    image_url: form.value.image_url.trim() || null,
    category: form.value.category.trim() || null,
    brand: form.value.brand.trim() || null,
  })
  onClose()
}

watch(
  () => props.modelValue,
  (val) => {
    if (!val) {
      resetForm()
    }
  },
)
</script>

<style scoped>
.border-top {
  border-top: 1px solid #e2e8f0;
}
</style>
