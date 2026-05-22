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
          >
            <template #prepend>
              <q-icon name="inventory_2" />
            </template>
          </q-input>

          <q-input
            v-model="form.image_url"
            label="Image URL"
            outlined
            dense
            :disable="isProductListInputType"
          >
            <template #prepend>
              <q-icon name="image" />
            </template>
          </q-input>

          <div v-if="form.image_url" class="q-mt-sm">
            <div class="text-subtitle2 q-mb-sm">Image Preview</div>
            <div style="margin: 0 auto; width: fit-content;">
              <SmartImage :src="form.image_url" style="max-width: 150px;" />
            </div>
          </div>

          <q-input
            v-model="form.barcode"
            label="Barcode"
            outlined
            dense
            :disable="isProductListInputType"
          >
            <template #prepend>
              <q-icon name="qr_code" />
            </template>
          </q-input>

          <q-input
            v-model="form.product_code"
            label="Product Code"
            outlined
            dense
            :disable="isProductListInputType"
          >
            <template #prepend>
              <q-icon name="badge" />
            </template>
          </q-input>

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
            :loading="store.saving"
            @update:model-value="onVendorOrMarketChange"
          >
            <template #prepend>
              <q-icon name="storefront" />
            </template>
          </q-select>

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
            :loading="store.saving"
            @update:model-value="onVendorOrMarketChange"
          >
            <template #prepend>
              <q-icon name="public" />
            </template>
          </q-select>

          <div class="row items-center q-col-gutter-sm">
            <div class="col">
              <q-select
                v-model="form.brand"
                :options="filteredBrandOptions"
                use-input
                fill-input
                input-debounce="0"
                clearable
                emit-value
                map-options
                label="Brand"
                outlined
                dense
                :disable="isProductListInputType || !canPickBrandCategory"
                @filter="filterBrandOptions"
                @input-value="onBrandInputValue"
              >
                <template #prepend>
                  <q-icon name="sell" />
                </template>
              </q-select>
            </div>
            <div class="col-auto">
              <q-btn
                color="primary"
                no-caps
                outline
                label="Add"
                :disable="isProductListInputType || !canAddBrand"
                @click="addBrandOption"
              />
            </div>
          </div>

          <div class="row items-center q-col-gutter-sm">
            <div class="col">
              <q-select
                v-model="form.category"
                :options="filteredCategoryOptions"
                use-input
                fill-input
                input-debounce="0"
                clearable
                emit-value
                map-options
                label="Category"
                outlined
                dense
                :disable="isProductListInputType || !canPickBrandCategory"
                @filter="filterCategoryOptions"
                @input-value="onCategoryInputValue"
              >
                <template #prepend>
                  <q-icon name="category" />
                </template>
              </q-select>
            </div>
            <div class="col-auto">
              <q-btn
                color="primary"
                no-caps
                outline
                label="Add"
                :disable="isProductListInputType || !canAddCategory"
                @click="addCategoryOption"
              />
            </div>
          </div>

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

          <q-input
            v-model.number="form.quantity"
            label="Quantity"
            type="number"
            outlined
            dense
            @wheel.prevent
          >
            <template #prepend>
              <q-icon name="numbers" />
            </template>
          </q-input>

          <q-input
            v-model="form.web_link"
            label="Web Link"
            outlined
            dense
          >
            <template #prepend>
              <q-icon name="link" />
            </template>
          </q-input>

          <q-input
            v-model.number="form.price_gbp"
            label="Price GBP"
            type="number"
            outlined
            dense
          >
            <template #prepend>
              <q-icon name="currency_pound" />
            </template>
          </q-input>

          <q-input
            v-model.number="form.product_weight"
            label="Product Weight"
            type="number"
            outlined
            dense
          >
            <template #prepend>
              <q-icon name="scale" />
            </template>
          </q-input>

          <q-input
            v-model.number="form.package_weight"
            label="Package Weight"
            type="number"
            outlined
            dense
          >
            <template #prepend>
              <q-icon name="fitness_center" />
            </template>
          </q-input>
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
import { computed, watch, reactive, ref } from 'vue'
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore'
import SmartImage from 'src/components/SmartImage.vue'
import { useProductStore } from 'src/modules/products/stores/productStore'
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore'
import { useMarketStore } from 'src/modules/market/stores/marketStore'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { productService } from 'src/modules/products/services/productService'
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback'

interface ProductBasedCostingItemFormData {
  id?: number
  product_based_costing_file_id?: number | null
  product_id?: number | null
  name?: string | null
  image_url?: string | null
  note?: string | null
  barcode?: string | null
  product_code?: string | null
  brand?: string | null
  category?: string | null
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
  defaultVendorCode?: string | null
  defaultMarketCode?: string | null
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
  barcode: '',
  product_code: '',
  brand: null as string | null,
  category: null as string | null,
  vendor_code: props.defaultVendorCode ?? null,
  market_code: props.defaultMarketCode ?? null,
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
      barcode: props.itemData.barcode ?? '',
      product_code: props.itemData.product_code ?? '',
      brand: props.itemData.brand ?? null,
      category: props.itemData.category ?? null,
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

const brandNames = ref<string[]>([])
const categoryNames = ref<string[]>([])
const filteredBrandNames = ref<string[]>([])
const filteredCategoryNames = ref<string[]>([])
const brandInputValue = ref('')
const categoryInputValue = ref('')

const filteredBrandOptions = computed(() => {
  const seen = new Set<string>()
  const options = filteredBrandNames.value
    .map((item) => (item ?? '').trim())
    .filter((item) => item.length > 0)
    .filter((item) => item.toLowerCase() !== 'other')
    .filter((item) => {
      const key = item.toLowerCase()
      if (seen.has(key)) return false
      seen.add(key)
      return true
    })
    .map((item) => ({
      label: item,
      value: item,
    }))

  return [{ label: 'Other', value: null as string | null }, ...options]
})

const filteredCategoryOptions = computed(() => {
  const seen = new Set<string>()
  const options = filteredCategoryNames.value
    .map((item) => (item ?? '').trim())
    .filter((item) => item.length > 0)
    .filter((item) => item.toLowerCase() !== 'other')
    .filter((item) => {
      const key = item.toLowerCase()
      if (seen.has(key)) return false
      seen.add(key)
      return true
    })
    .map((item) => ({
      label: item,
      value: item,
    }))

  return [{ label: 'Other', value: null as string | null }, ...options]
})

const canPickBrandCategory = computed(
  () => Boolean(form.vendor_code) && Boolean(form.market_code),
)

const normalized = (value: string | null | undefined) => (value ?? '').trim()

const normalizeKey = (value: string | null | undefined) =>
  normalized(value).toLowerCase()

const canAddBrand = computed(() => {
  if (!canPickBrandCategory.value || !form.vendor_code) return false
  const candidate = normalized(brandInputValue.value || form.brand)
  if (!candidate) return false
  return !brandNames.value.some((item) => normalizeKey(item) === normalizeKey(candidate))
})

const canAddCategory = computed(() => {
  if (!canPickBrandCategory.value || !form.vendor_code) return false
  const candidate = normalized(categoryInputValue.value || form.category)
  if (!candidate) return false
  return !categoryNames.value.some((item) => normalizeKey(item) === normalizeKey(candidate))
})

const loadBrandCategoryOptions = async () => {
  if (!form.vendor_code || !form.market_code) {
    brandNames.value = []
    categoryNames.value = []
    filteredBrandNames.value = []
    filteredCategoryNames.value = []
    return
  }

  const [brandResult, categoryResult] = await Promise.all([
    productService.listBrands({ vendorCode: form.vendor_code, tenantId: authStore.tenantId ?? null }),
    productService.listCategories({ vendorCode: form.vendor_code, tenantId: authStore.tenantId ?? null }),
  ])

  if (brandResult.success) {
    brandNames.value = brandResult.data ?? []
    filteredBrandNames.value = [...brandNames.value]
  } else {
    handleApiFailure(brandResult, brandResult.error ?? 'Failed to load brands.')
  }

  if (categoryResult.success) {
    categoryNames.value = categoryResult.data ?? []
    filteredCategoryNames.value = [...categoryNames.value]
  } else {
    handleApiFailure(categoryResult, categoryResult.error ?? 'Failed to load categories.')
  }
}

const filterBrandOptions = (val: string, update: (callback: () => void) => void) => {
  const needle = normalizeKey(val)
  update(() => {
    if (!needle) {
      filteredBrandNames.value = [...brandNames.value]
      return
    }
    filteredBrandNames.value = brandNames.value.filter(
      (item) => normalizeKey(item).includes(needle),
    )
  })
}

const filterCategoryOptions = (val: string, update: (callback: () => void) => void) => {
  const needle = normalizeKey(val)
  update(() => {
    if (!needle) {
      filteredCategoryNames.value = [...categoryNames.value]
      return
    }
    filteredCategoryNames.value = categoryNames.value.filter(
      (item) => normalizeKey(item).includes(needle),
    )
  })
}

const onBrandInputValue = (value: string) => {
  brandInputValue.value = value
}

const onCategoryInputValue = (value: string) => {
  categoryInputValue.value = value
}

const addBrandOption = async () => {
  const name = normalized(brandInputValue.value || form.brand)
  if (!name || !form.vendor_code) return

  const selectedVendor = vendorStore.items.find((v) => v.code === form.vendor_code)
  const result = await productService.createProductBrand({
    name,
    value: name.toLowerCase(),
    vendor_code: form.vendor_code,
    vendor_id: selectedVendor ? selectedVendor.id : null,
  })

  if (!result.success) {
    handleApiFailure(result, result.error ?? 'Failed to add brand.')
    return
  }

  showSuccessNotification('Brand added successfully.')
  await loadBrandCategoryOptions()
  form.brand = name
  brandInputValue.value = ''
}

const addCategoryOption = async () => {
  const name = normalized(categoryInputValue.value || form.category)
  if (!name || !form.vendor_code) return

  const selectedVendor = vendorStore.items.find((v) => v.code === form.vendor_code)
  const result = await productService.createProductCategory({
    name,
    value: name.toLowerCase(),
    vendor_code: form.vendor_code,
    vendor_id: selectedVendor ? selectedVendor.id : null,
  })

  if (!result.success) {
    handleApiFailure(result, result.error ?? 'Failed to add category.')
    return
  }

  showSuccessNotification('Category added successfully.')
  await loadBrandCategoryOptions()
  form.category = name
  categoryInputValue.value = ''
}

const submitForm = async () => {
  if (!form.vendor_code || !form.market_code) {
    handleApiFailure(
      { success: false, error: 'Please select vendor and market first.' },
      'Please select vendor and market first.',
    )
    return
  }

  if (isEditMode.value && props.itemData?.id) {
    const result = await store.updateProductBasedCostingItem({
      id: props.itemData.id,
      product_based_costing_file_id: props.productBasedCostingFileId,
      name: form.name,
      image_url: form.image_url,
      note: form.note,
      barcode: form.barcode,
      product_code: form.product_code,
      brand: form.brand,
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

    if (props.itemData.product_id != null) {
      await productStore.updateProduct({
        id: props.itemData.product_id,
        brand: form.brand || null,
        category: form.category || null,
      })
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
    barcode: form.barcode || null,
    product_code: form.product_code || null,
    price_gbp: form.price_gbp,
    country_of_origin: null,
        brand: form.brand || null,
        category: form.category || null,
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
    barcode: form.barcode,
    product_code: form.product_code,
    brand: form.brand,
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
  async ([value]) => {
    if (value) {
      fillForm()
      if (!vendorStore.items.length) {
        await vendorStore.fetchVendors(authStore.tenantId ?? null)
      }
      if (!marketStore.items.length) {
        await marketStore.fetchMarkets()
      }
      await loadBrandCategoryOptions()
    }
  },
  { immediate: true, deep: true },
)

watch(
  () => [props.defaultVendorCode, props.defaultMarketCode, props.modelValue, props.itemData],
  (values) => {
    const vendorCode = (values[0] ?? null) as string | null
    const marketCode = (values[1] ?? null) as string | null
    const isOpen = Boolean(values[2])
    const itemData = (values[3] ?? null) as ProductBasedCostingItemFormData | null

    if (!isOpen) {
      return
    }
    if (itemData?.id) {
      return
    }
    form.vendor_code = vendorCode ?? null
    form.market_code = marketCode ?? null
    void loadBrandCategoryOptions()
  },
)

  const onVendorOrMarketChange = async () => {
  if (!isEditMode.value) {
    form.brand = null
    form.category = null
  }
  await loadBrandCategoryOptions()

  const result = await store.updateProductBasedCostingFile({
    id: props.productBasedCostingFileId,
    vendor_code: form.vendor_code,
    market_code: form.market_code,
  })

  if (!result.success) {
    return
  }
}
</script>

<style scoped>
.border {
  border: 1px solid #e0e0e0;
}
</style>
