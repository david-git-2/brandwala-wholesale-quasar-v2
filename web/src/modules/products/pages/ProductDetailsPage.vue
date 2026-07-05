<template>
  <q-page class="q-pa-md product-details-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-auto row items-center q-gutter-sm">
            <q-badge color="primary" outline class="text-weight-medium">#{{ product?.id ?? '-' }}</q-badge>
            <div class="text-h6 text-weight-bold">{{ product?.name ?? 'Product Details' }}</div>
          </div>
          <div v-if="product && !loading" class="col-auto row items-center q-gutter-sm">
            <template v-if="!isEditing">
              <q-btn
                color="negative"
                flat
                round
                dense
                icon="o_delete"
                :loading="deleting"
                @click="confirmDelete"
              >
                <q-tooltip>Delete Product</q-tooltip>
              </q-btn>
              <q-btn
                color="primary"
                no-caps
                label="Edit Product"
                icon="o_edit"
                class="pill-btn slim-btn"
                @click="startEdit"
              />
            </template>
            <template v-else>
              <q-btn
                color="positive"
                no-caps
                label="Save"
                icon="save"
                :loading="updating"
                class="pill-btn slim-btn"
                @click="onSave"
              />
              <q-btn
                flat
                no-caps
                label="Cancel"
                :disable="updating"
                class="pill-btn slim-btn"
                @click="cancelEdit"
              />
            </template>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <PageInitialLoader v-if="loading" />
    <q-banner v-else-if="error" class="bg-red-1 text-negative q-mb-md">
      {{ error }}
    </q-banner>

    <q-card v-else-if="product" flat class="floating-surface shadow-1">
      <q-card-section>
        <div class="row q-col-gutter-md">
          <!-- Left side: image preview and image url edit -->
          <div class="col-12 col-md-4">
            <div class="details-image-wrap q-mb-md">
              <SmartImage
                :src="isEditing ? form.image_url : (product?.image_url ?? '')"
                @update:src="val => { if (isEditing) form.image_url = val; else if (product) product.image_url = val; }"
                :product-id="isEditing ? null : (product?.id ?? null)"
                :alt="(isEditing ? form.name : product?.name) ?? ''"
                imgClass="details-image"
                fallbackClass="details-image-fallback"
              />
            </div>
            <div v-if="isEditing" class="q-px-xs">
              <q-input
                v-model="form.image_url"
                label="Image URL"
                outlined
                dense
                hide-bottom-space
                class="soft-input"
              >
                <template #prepend>
                  <q-icon name="image" />
                </template>
              </q-input>
            </div>
          </div>

          <!-- Right side: product info display or edit form -->
          <div class="col-12 col-md-8">
            <template v-if="!isEditing">
              <div class="row q-col-gutter-sm">
                <div v-for="row in detailRows" :key="row.label" class="col-12 col-sm-6">
                  <q-card flat bordered class="q-pa-sm full-height">
                    <div class="text-caption text-grey-7">{{ row.label }}</div>
                    <div class="text-body2 text-weight-medium">{{ row.value }}</div>
                  </q-card>
                </div>
              </div>
            </template>
            <template v-else>
              <q-form ref="formRef" class="row q-col-gutter-sm">
                <div class="col-12">
                  <q-input
                    v-model="form.name"
                    label="Product Name *"
                    outlined
                    dense
                    class="soft-input"
                    :rules="[val => !!val || 'Name is required']"
                  >
                    <template #prepend>
                      <q-icon name="assignment" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model="form.product_code"
                    label="Product Code"
                    outlined
                    dense
                    class="soft-input"
                  >
                    <template #prepend>
                      <q-icon name="qr_code" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model="form.barcode"
                    label="Barcode"
                    outlined
                    dense
                    class="soft-input"
                  >
                    <template #prepend>
                      <q-icon name="barcode_reader" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-6">
                  <q-select
                    v-model="form.brand"
                    :options="brandOptions"
                    label="Brand"
                    outlined
                    dense
                    use-input
                    fill-input
                    hide-selected
                    input-debounce="0"
                    @filter="filterBrands"
                    @new-value="createBrandValue"
                    class="soft-input"
                    clearable
                  >
                    <template #prepend>
                      <q-icon name="storefront" />
                    </template>
                  </q-select>
                </div>
                <div class="col-12 col-sm-6">
                  <q-select
                    v-model="form.category"
                    :options="categoryOptions"
                    label="Category"
                    outlined
                    dense
                    use-input
                    fill-input
                    hide-selected
                    input-debounce="0"
                    @filter="filterCategories"
                    @new-value="createCategoryValue"
                    class="soft-input"
                    clearable
                  >
                    <template #prepend>
                      <q-icon name="category" />
                    </template>
                  </q-select>
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="form.list_price_amount"
                    label="List Price"
                    type="number"
                    step="0.01"
                    outlined
                    dense
                    class="soft-input"
                  />
                </div>
                <div class="col-12 col-sm-6">
                  <q-select
                    v-model="form.list_price_currency_id"
                    :options="currencies"
                    label="List Price Currency"
                    outlined
                    dense
                    emit-value
                    map-options
                    class="soft-input"
                  />
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="form.reference_cost_amount"
                    label="Reference Cost"
                    type="number"
                    step="0.01"
                    outlined
                    dense
                    class="soft-input"
                  />
                </div>
                <div class="col-12 col-sm-6">
                  <q-select
                    v-model="form.reference_cost_currency_id"
                    :options="currencies"
                    label="Reference Cost Currency"
                    outlined
                    dense
                    emit-value
                    map-options
                    class="soft-input"
                  />
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="form.available_units"
                    label="Original Stock"
                    type="number"
                    outlined
                    dense
                    class="soft-input"
                  >
                    <template #prepend>
                      <q-icon name="inventory_2" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="form.minimum_order_quantity"
                    label="Minimum Order Quantity"
                    type="number"
                    outlined
                    dense
                    class="soft-input"
                  >
                    <template #prepend>
                      <q-icon name="shopping_cart" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model="form.country_of_origin"
                    label="Country Of Origin"
                    outlined
                    dense
                    class="soft-input"
                  >
                    <template #prepend>
                      <q-icon name="public" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model="form.tariff_code"
                    label="Tariff Code"
                    outlined
                    dense
                    class="soft-input"
                  >
                    <template #prepend>
                      <q-icon name="description" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model="form.languages"
                    label="Languages"
                    outlined
                    dense
                    class="soft-input"
                  >
                    <template #prepend>
                      <q-icon name="translate" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model="form.batch_code_manufacture_date"
                    label="Batch Code / MFG Date"
                    outlined
                    dense
                    class="soft-input"
                  >
                    <template #prepend>
                      <q-icon name="date_range" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model="form.expire_date"
                    label="Expire Date"
                    outlined
                    dense
                    class="soft-input"
                  >
                    <template #prepend>
                      <q-icon name="event_busy" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="form.product_weight"
                    label="Product Weight (g)"
                    type="number"
                    step="0.001"
                    outlined
                    dense
                    class="soft-input"
                  >
                    <template #prepend>
                      <q-icon name="scale" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model.number="form.package_weight"
                    label="Package Weight (g)"
                    type="number"
                    step="0.001"
                    outlined
                    dense
                    class="soft-input"
                  >
                    <template #prepend>
                      <q-icon name="scale" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-6">
                  <q-select
                    v-model="form.vendor_code"
                    :options="vendorOptions"
                    label="Vendor"
                    outlined
                    dense
                    emit-value
                    map-options
                    use-input
                    input-debounce="0"
                    @filter="filterVendors"
                    class="soft-input"
                    clearable
                  >
                    <template #prepend>
                      <q-icon name="badge" />
                    </template>
                  </q-select>
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model="form.market_code"
                    label="Market Code"
                    outlined
                    dense
                    class="soft-input"
                  >
                    <template #prepend>
                      <q-icon name="explore" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-6 row items-center q-pl-md">
                  <q-toggle
                    v-model="form.is_available"
                    label="Is Available"
                    color="primary"
                  />
                </div>
              </q-form>
            </template>
          </div>
        </div>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import SmartImage from 'src/components/SmartImage.vue'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import type { Product } from '../types'
import { productService } from '../services/productService'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { vendorService } from 'src/modules/vendor/services/vendorService'
import type { Vendor } from 'src/modules/vendor/types'
import type { QForm } from 'quasar'
import { showSuccessNotification } from 'src/utils/appFeedback'
import { globalReferenceRepository } from 'src/modules/global_reference/repositories/globalReferenceRepository'

const route = useRoute()
const router = useRouter()
const $q = useQuasar()
const authStore = useAuthStore()

const loading = ref(false)
const deleting = ref(false)
const updating = ref(false)
const error = ref<string | null>(null)
const product = ref<Product | null>(null)
const isEditing = ref(false)
const formRef = ref<QForm | null>(null)

const brandsList = ref<string[]>([])
const categoriesList = ref<string[]>([])
const vendorsList = ref<Vendor[]>([])

const brandOptions = ref<string[]>([])
const categoryOptions = ref<string[]>([])
const vendorOptions = ref<{ label: string; value: string }[]>([])
const currencies = ref<{ label: string; value: number }[]>([])

const form = reactive({
  name: '',
  image_url: '',
  product_code: '',
  barcode: '',
  brand: '',
  category: '',
  list_price_amount: null as number | null,
  list_price_currency_id: null as number | null,
  reference_cost_amount: null as number | null,
  reference_cost_currency_id: null as number | null,
  available_units: null as number | null,
  minimum_order_quantity: null as number | null,
  country_of_origin: '',
  tariff_code: '',
  languages: '',
  batch_code_manufacture_date: '',
  expire_date: '',
  product_weight: null as number | null,
  package_weight: null as number | null,
  vendor_code: '',
  market_code: '',
  is_available: true,
})

const detailRows = computed(() => {
  const item = product.value
  if (!item) return []

  const getCurrencySymbol = (id: number | null) => {
    if (!id) return ''
    const match = currencies.value.find(c => c.value === id)
    if (!match) return ''
    const parts = match.label.match(/\(([^)]+)\)/)
    return parts ? parts[1] : ''
  }

  const formatMoney = (amount: number | null, currencyId: number | null) => {
    if (amount == null) return '-'
    const symbol = getCurrencySymbol(currencyId)
    return `${symbol}${Number(amount).toFixed(2)}`
  }

  return [
    { label: 'Product Code', value: item.product_code ?? '-' },
    { label: 'Barcode', value: item.barcode ?? '-' },
    { label: 'Brand', value: item.brand ?? '-' },
    { label: 'Category', value: item.category ?? '-' },
    { label: 'List Price', value: formatMoney(item.list_price_amount, item.list_price_currency_id) },
    { label: 'Reference Cost', value: formatMoney(item.reference_cost_amount, item.reference_cost_currency_id) },
    { label: 'Original Stock', value: item.available_units ?? '-' },
    { label: 'Minimum Order Quantity', value: item.minimum_order_quantity ?? '-' },
    { label: 'Country Of Origin', value: item.country_of_origin ?? '-' },
    { label: 'Tariff Code', value: item.tariff_code ?? '-' },
    { label: 'Languages', value: item.languages ?? '-' },
    { label: 'Batch Code / MFG Date', value: item.batch_code_manufacture_date ?? '-' },
    { label: 'Expire Date', value: item.expire_date ?? '-' },
    { label: 'Product Weight', value: item.product_weight ?? '-' },
    { label: 'Package Weight', value: item.package_weight ?? '-' },
    { label: 'Vendor', value: item.vendor_code ?? '-' },
    { label: 'Market', value: item.market_code ?? '-' },
    { label: 'Status', value: item.is_available ? 'Available' : 'Unavailable' },
    { label: 'Updated At', value: item.updated_at ?? '-' },
  ]
})

const loadLookupData = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  const [brandsRes, categoriesRes, vendorsRes] = await Promise.all([
    productService.listBrands({ tenantId }),
    productService.listCategories({ tenantId }),
    vendorService.listVendors(tenantId),
  ])

  if (brandsRes.success && brandsRes.data) {
    brandsList.value = brandsRes.data.filter(Boolean)
  }
  if (categoriesRes.success && categoriesRes.data) {
    categoriesList.value = categoriesRes.data.filter(Boolean)
  }
  if (vendorsRes.success && vendorsRes.data) {
    vendorsList.value = vendorsRes.data
  }
}

const filterBrands = (val: string, update: (cb: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase()
    brandOptions.value = brandsList.value.filter(
      v => v && v.toLowerCase().indexOf(needle) > -1
    )
  })
}

const createBrandValue = (val: string, done: (item?: unknown, mode?: 'toggle' | 'add' | 'add-unique') => void) => {
  if (val.length > 0) {
    const capitalized = val.toUpperCase()
    if (!brandsList.value.includes(capitalized)) {
      brandsList.value.push(capitalized)
    }
    done(capitalized, 'add-unique')
  }
}

const filterCategories = (val: string, update: (cb: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase()
    categoryOptions.value = categoriesList.value.filter(
      v => v && v.toLowerCase().indexOf(needle) > -1
    )
  })
}

const createCategoryValue = (val: string, done: (item?: unknown, mode?: 'toggle' | 'add' | 'add-unique') => void) => {
  if (val.length > 0) {
    if (!categoriesList.value.includes(val)) {
      categoriesList.value.push(val)
    }
    done(val, 'add-unique')
  }
}

const filterVendors = (val: string, update: (cb: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase()
    vendorOptions.value = vendorsList.value
      .filter(v => v.name.toLowerCase().indexOf(needle) > -1 || v.code.toLowerCase().indexOf(needle) > -1)
      .map(v => ({ label: `${v.name} (${v.code})`, value: v.code }))
  })
}

const startEdit = () => {
  if (!product.value) return
  form.name = product.value.name ?? ''
  form.image_url = product.value.image_url ?? ''
  form.product_code = product.value.product_code ?? ''
  form.barcode = product.value.barcode ?? ''
  form.brand = product.value.brand ?? ''
  form.category = product.value.category ?? ''
  form.list_price_amount = product.value.list_price_amount
  form.list_price_currency_id = product.value.list_price_currency_id
  form.reference_cost_amount = product.value.reference_cost_amount
  form.reference_cost_currency_id = product.value.reference_cost_currency_id
  form.available_units = product.value.available_units
  form.minimum_order_quantity = product.value.minimum_order_quantity
  form.country_of_origin = product.value.country_of_origin ?? ''
  form.tariff_code = product.value.tariff_code ?? ''
  form.languages = product.value.languages ?? ''
  form.batch_code_manufacture_date = product.value.batch_code_manufacture_date ?? ''
  form.expire_date = product.value.expire_date ?? ''
  form.product_weight = product.value.product_weight
  form.package_weight = product.value.package_weight
  form.vendor_code = product.value.vendor_code ?? ''
  form.market_code = product.value.market_code ?? ''
  form.is_available = product.value.is_available ?? true
  isEditing.value = true
}

const cancelEdit = () => {
  isEditing.value = false
}

const confirmDelete = () => {
  $q.dialog({
    title: 'Confirm Deletion',
    message: 'Are you sure you want to delete this product? This action cannot be undone.',
    persistent: true,
    ok: {
      color: 'negative',
      label: 'Delete',
      noCaps: true,
      flat: false,
    },
    cancel: {
      flat: true,
      noCaps: true,
    },
  }).onOk(() => {
    void onDelete()
  })
}

const onDelete = async () => {
  if (!product.value) return
  deleting.value = true
  error.value = null
  try {
    const result = await productService.deleteProduct({ id: product.value.id })
    if (!result.success) {
      error.value = result.error ?? 'Failed to delete product.'
      return
    }
    showSuccessNotification('Product deleted successfully.')
    const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
    await router.push(`${tenantPrefix}/app/products`)
  } catch (err) {
    console.error('Error deleting product:', err)
    error.value = err instanceof Error ? err.message : String(err)
  } finally {
    deleting.value = false
  }
}

const cleanNumber = (val: number | string | null | undefined): number | null => {
  if (val === '' || val == null) return null
  const parsed = Number(val)
  return Number.isFinite(parsed) ? parsed : null
}

const onSave = async () => {
  if (!product.value) return
  if (formRef.value) {
    const isValid = await formRef.value.validate()
    if (!isValid) return
  }

  updating.value = true
  error.value = null
  try {
    const result = await productService.updateProduct({
      id: product.value.id,
      name: form.name.trim(),
      image_url: form.image_url.trim() || null,
      product_code: form.product_code.trim() || null,
      barcode: form.barcode.trim() || null,
      brand: form.brand.trim() || null,
      category: form.category.trim() || null,
      list_price_amount: cleanNumber(form.list_price_amount),
      list_price_currency_id: form.list_price_currency_id,
      reference_cost_amount: cleanNumber(form.reference_cost_amount),
      reference_cost_currency_id: form.reference_cost_currency_id,
      available_units: cleanNumber(form.available_units),
      minimum_order_quantity: cleanNumber(form.minimum_order_quantity),
      country_of_origin: form.country_of_origin.trim() || null,
      tariff_code: form.tariff_code.trim() || null,
      languages: form.languages.trim() || null,
      batch_code_manufacture_date: form.batch_code_manufacture_date.trim() || null,
      expire_date: form.expire_date.trim() || null,
      product_weight: cleanNumber(form.product_weight),
      package_weight: cleanNumber(form.package_weight),
      vendor_code: form.vendor_code.trim() || null,
      market_code: form.market_code.trim() || null,
      is_available: form.is_available,
    })

    if (!result.success) {
      error.value = result.error ?? 'Failed to update product.'
      return
    }

    product.value = result.data ?? null
    isEditing.value = false
  } finally {
    updating.value = false
  }
}

onMounted(async () => {
  const id = Number(route.params.id)
  if (!Number.isFinite(id) || id <= 0) {
    error.value = 'Invalid product id.'
    return
  }

  loading.value = true
  error.value = null

  try {
    try {
      const currencyData = await globalReferenceRepository.listCurrencies()
      currencies.value = currencyData
        .filter(c => c.is_active)
        .map(c => ({ label: `${c.code} (${c.symbol})`, value: c.id }))
    } catch (e) {
      console.error('Error fetching currencies:', e)
    }

    const result = await productService.getProductById(id, authStore.tenantId)
    if (!result.success) {
      error.value = result.error ?? 'Failed to load product.'
      return
    }
    product.value = result.data ?? null
    await loadLookupData()
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.product-details-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 12px;
  padding-right: 12px;
}

.details-image-wrap {
  border: 1px solid rgba(34, 56, 101, 0.12);
  border-radius: 12px;
  overflow: hidden;
  background: #fff;
  height: 320px;
}

.details-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.details-image-fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #eef2f6;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
</style>
